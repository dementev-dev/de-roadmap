from __future__ import annotations

import json
import os
import random
from datetime import datetime, timedelta
from typing import List, Tuple, Optional

from airflow import DAG
from airflow.operators.python import PythonOperator
from confluent_kafka import Consumer, KafkaException, Producer
from psycopg2.extras import execute_values

from helpers.greenplum import get_gp_conn

KAFKA_BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "kafka:9092")
TOPIC = os.getenv("KAFKA_TOPIC", "orders")
BATCH_SIZE = int(os.getenv("KAFKA_BATCH_SIZE", "500"))
POLL_TIMEOUT_S = int(os.getenv("KAFKA_POLL_TIMEOUT", "10"))
def _create_table():
    ddl = """
    CREATE TABLE IF NOT EXISTS public.orders (
        order_id BIGINT,
        order_ts TIMESTAMP NOT NULL,
        customer_id BIGINT NOT NULL,
        amount NUMERIC(12,2) NOT NULL
    )
    WITH (appendonly=true, orientation=column, compresstype=zlib)
    DISTRIBUTED BY (order_id);
    """
    with get_gp_conn() as conn, conn.cursor() as cur:
        cur.execute(ddl)
        conn.commit()


def _produce(n=1000):
    producer = Producer({"bootstrap.servers": KAFKA_BOOTSTRAP})
    for idx in range(n):
        payload = {
            "order_id": idx + 1,
            "order_ts": datetime.utcnow().isoformat(),
            "customer_id": random.randint(1, 100),
            "amount": round(random.uniform(10, 500), 2),
        }
        producer.produce(TOPIC, json.dumps(payload).encode("utf-8"))
    producer.flush()


def _flush_batch(cur, rows: List[Tuple]):
    """Insert deduplicated batch of rows into public.orders for GP6 (no PK support)."""
    if not rows:
        return
    # Дедупликация внутри батча по первичному ключу (order_id)
    by_id = {int(r[0]): r for r in rows}
    unique_rows = list(by_id.values())

    # Вставка через VALUES + anti-join для GP6 (без ON CONFLICT)
    execute_values(
        cur,
        """
        INSERT INTO public.orders(order_id, order_ts, customer_id, amount)
        SELECT v.order_id, v.order_ts, v.customer_id, v.amount
        FROM (VALUES %s) AS v(order_id, order_ts, customer_id, amount)
        LEFT JOIN public.orders o ON o.order_id = v.order_id
        WHERE o.order_id IS NULL
        """,
        unique_rows,
        template="(%s,%s,%s,%s)",
    )


def _consume_and_load(max_messages=1000, timeout_s: Optional[int] = None):
    if timeout_s is None:
        timeout_s = POLL_TIMEOUT_S

    consumer = Consumer(
        {
            "bootstrap.servers": KAFKA_BOOTSTRAP,
            "group.id": "airflow-loader-gp",
            "auto.offset.reset": "earliest",
            "enable.auto.commit": False,
        }
    )
    consumer.subscribe([TOPIC])

    with get_gp_conn() as conn, conn.cursor() as cur:
        batch: List[Tuple] = []
        consumed = 0
        while consumed < max_messages:
            msg = consumer.poll(timeout_s)
            if msg is None:
                # Нет новых сообщений — сбрасываем остаток батча и выходим
                if batch:
                    _flush_batch(cur, batch)
                    conn.commit()
                    batch.clear()
                break
            if msg.error():
                raise KafkaException(msg.error())

            data = json.loads(msg.value().decode("utf-8"))
            batch.append(
                (
                    int(data["order_id"]),
                    data["order_ts"],
                    int(data["customer_id"]),
                    float(data["amount"]),
                )
            )
            consumed += 1

            if len(batch) >= BATCH_SIZE:
                _flush_batch(cur, batch)
                conn.commit()
                batch.clear()

        # Финальный сброс, если вышли по лимиту сообщений
        if batch:
            _flush_batch(cur, batch)
            conn.commit()

    # Фиксируем оффсеты после успешной загрузки
    consumer.commit()
    consumer.close()


default_args = {"owner": "airflow", "retries": 1, "retry_delay": timedelta(seconds=30)}

with DAG(
    dag_id="kafka_to_greenplum",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    default_args=default_args,
    tags=["demo", "kafka", "greenplum"],
) as dag:
    create_table = PythonOperator(task_id="create_table", python_callable=_create_table)
    produce = PythonOperator(
        task_id="produce_messages", python_callable=_produce, op_kwargs={"n": 1000}
    )
    consume_and_load = PythonOperator(
        task_id="consume_and_load",
        python_callable=_consume_and_load,
        op_kwargs={"max_messages": 1000},
    )

    create_table >> produce >> consume_and_load
