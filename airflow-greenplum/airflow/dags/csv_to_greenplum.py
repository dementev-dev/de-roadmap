from __future__ import annotations

import logging
import os
import random
from datetime import datetime, timedelta
from pathlib import Path
from typing import List

import pandas as pd
from airflow import DAG
from airflow.operators.python import PythonOperator
from helpers.greenplum import get_gp_conn

CSV_DIR = Path(os.getenv("CSV_DIR", "/opt/airflow/data"))
CSV_ROWS = int(os.getenv("CSV_ROWS", "1000"))


def _create_table() -> None:
    """Создаёт таблицу public.orders, если она ещё не существует."""
    ddl = """
    CREATE TABLE IF NOT EXISTS public.orders (
        order_id BIGINT,
        order_ts TIMESTAMP NOT NULL,
        customer_id BIGINT NOT NULL,
        amount NUMERIC(12,2) NOT NULL
    )
    WITH (appendonly=true, orientation=row, compresstype=zlib, compresslevel=1)
    DISTRIBUTED BY (order_id);
    """
    with get_gp_conn() as conn, conn.cursor() as cur:
        cur.execute(ddl)
        conn.commit()


def _generate_csv(rows: int, csv_dir: Path) -> str:
    """Генерирует CSV c заказами с помощью pandas и сохраняет на диск."""
    csv_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    csv_path = csv_dir / f"orders_{timestamp}.csv"

    # Генерируем данные в pandas-стиле
    base_order_id = int(datetime.utcnow().timestamp() * 1_000)
    
    # Создаём DataFrame с использованием pandas методов
    df = pd.DataFrame({
        # Уникальные order_id начиная с базового значения
        "order_id": pd.Series(range(base_order_id, base_order_id + rows), dtype="int64"),
        
        # Временные метки с интервалом в 1 секунду в обратном порядке
        "order_ts": pd.date_range(
            end=datetime.utcnow(),
            periods=rows,
            freq="1S"
        ).sort_values(ascending=False),
        
        # Случайные customer_id от 1 до 1000
        "customer_id": pd.Series(
            random.choices(range(1, 1001), k=rows),
            dtype="int64"
        ),
        
        # Случайные суммы от 10 до 500 с округлением до 2 знаков
        "amount": pd.Series(
            [round(random.uniform(10, 500), 2) for _ in range(rows)],
            dtype="float64"
        )
    })
    
    # Сохраняем CSV без индекса
    df.to_csv(csv_path, index=False)
    logging.info("CSV сохранён: %s (строк: %s)", csv_path, len(df))
    return str(csv_path)


def _preview_csv(csv_path: str, sample_rows: int = 5) -> None:
    """Отображает предпросмотр CSV через pandas (head и describe)."""
    df = pd.read_csv(csv_path)
    df["order_ts"] = pd.to_datetime(df["order_ts"], errors="coerce")
    logging.info("Первые %s строк:\n%s", sample_rows, df.head(sample_rows).to_string(index=False))
    numeric_summary = df.describe(include="number")
    logging.info("Числовая статистика:\n%s", numeric_summary.to_string())
    if df["order_ts"].notna().any():
        logging.info(
            "Диапазон order_ts: %s → %s",
            df["order_ts"].min().isoformat(),
            df["order_ts"].max().isoformat(),
        )


def _load_csv(csv_path: str) -> None:
    """Загружает CSV в Greenplum через временную таблицу и anti-join."""
    csv_file = Path(csv_path)
    if not csv_file.exists():
        raise FileNotFoundError(f"CSV не найден: {csv_file}")

    with get_gp_conn() as conn, conn.cursor() as cur, csv_file.open("r", encoding="utf-8") as f:
        cur.execute("CREATE TEMP TABLE tmp_orders (LIKE public.orders INCLUDING DEFAULTS) ON COMMIT DROP;")
        cur.copy_expert(
            "COPY tmp_orders (order_id, order_ts, customer_id, amount) FROM STDIN WITH CSV HEADER",
            f,
        )

        cur.execute("SELECT COUNT(*) FROM tmp_orders")
        tmp_rows = cur.fetchone()[0]

        cur.execute(
            """
            INSERT INTO public.orders(order_id, order_ts, customer_id, amount)
            SELECT t.order_id, t.order_ts, t.customer_id, t.amount
            FROM tmp_orders t
            LEFT JOIN public.orders o ON o.order_id = t.order_id
            WHERE o.order_id IS NULL
            """
        )
        inserted = cur.rowcount if cur.rowcount != -1 else 0
        conn.commit()

    logging.info("Загружено строк: %s (прочитано из CSV: %s)", inserted, tmp_rows)


default_args = {"owner": "airflow", "retries": 1, "retry_delay": timedelta(seconds=30)}

with DAG(
    dag_id="csv_to_greenplum",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    default_args=default_args,
    tags=["demo", "greenplum", "csv"],
) as dag:
    create_table = PythonOperator(
        task_id="create_orders_table",
        python_callable=_create_table,
    )

    generate_csv = PythonOperator(
        task_id="generate_csv",
        python_callable=_generate_csv,
        op_kwargs={"rows": CSV_ROWS, "csv_dir": CSV_DIR},
    )

    preview_csv = PythonOperator(
        task_id="preview_csv",
        python_callable=_preview_csv,
        op_kwargs={
            "csv_path": "{{ ti.xcom_pull(task_ids='generate_csv') }}",
            "sample_rows": 5,
        },
    )

    load_csv = PythonOperator(
        task_id="load_csv_to_greenplum",
        python_callable=_load_csv,
        op_kwargs={
            "csv_path": "{{ ti.xcom_pull(task_ids='generate_csv') }}",
        },
    )

    create_table >> generate_csv >> preview_csv >> load_csv
