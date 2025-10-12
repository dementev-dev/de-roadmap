from __future__ import annotations

import os
from typing import List, Sequence, Tuple

import psycopg2

# Настройки для подключения к Greenplum. По умолчанию используем Airflow Connection,
# но при проблемах можно переключиться на ENV-подключение, установив GP_USE_AIRFLOW_CONN=false.
GP_CONN_ID = os.getenv("GP_CONN_ID", "greenplum_conn")
GP_USE_AIRFLOW_CONN = os.getenv("GP_USE_AIRFLOW_CONN", "true").lower() in ("1", "true", "yes")

EXPECTED_ORDERS_SCHEMA: List[Tuple[str, str]] = [
    ("order_id", "bigint"),
    ("order_ts", "timestamp without time zone"),
    ("customer_id", "bigint"),
    ("amount", "numeric"),
]


def get_gp_conn():
    """Возвращает psycopg2 connection к Greenplum (через Airflow Connection или напрямую по ENV)."""
    if GP_USE_AIRFLOW_CONN:
        try:
            from airflow.providers.postgres.hooks.postgres import PostgresHook

            hook = PostgresHook(postgres_conn_id=GP_CONN_ID)
            return hook.get_conn()
        except Exception:
            # Фоллбек на прямое подключение по переменным окружения.
            pass

    return psycopg2.connect(
        dbname=os.getenv("GP_DB", "gpadmin"),
        user=os.getenv("GP_USER", "gpadmin"),
        password=os.getenv("GP_PASSWORD", ""),
        host=os.getenv("GP_HOST", "greenplum"),
        port=int(os.getenv("GP_PORT", "5432")),
    )


def assert_orders_table_exists(conn) -> None:
    """Проверяет наличие таблицы orders в схеме public."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT 1
            FROM pg_catalog.pg_tables
            WHERE schemaname = 'public' AND tablename = 'orders'
            """
        )
        if cur.fetchone() is None:
            raise ValueError("Таблица public.orders не найдена; запусти DAG kafka_to_greenplum.")


def fetch_orders_schema(conn) -> Sequence[Tuple[str, str]]:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'orders'
            ORDER BY ordinal_position
            """
        )
        return cur.fetchall()


def assert_orders_schema(conn) -> None:
    """Проверяет, что схема таблицы orders соответствует ожидаемой."""
    schema = fetch_orders_schema(conn)
    if list(schema) != EXPECTED_ORDERS_SCHEMA:
        raise ValueError(f"Неожиданная схема orders: {schema}. Ожидали {EXPECTED_ORDERS_SCHEMA}.")


def fetch_orders_count(conn) -> int:
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM public.orders")
        return cur.fetchone()[0]


def assert_orders_have_rows(conn) -> None:
    """Проверяет, что таблица orders не пустая."""
    if fetch_orders_count(conn) <= 0:
        raise ValueError("Таблица public.orders пустая — запусти DAG kafka_to_greenplum перед проверкой.")


def fetch_orders_duplicates(conn) -> int:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT COUNT(*) FROM (
                SELECT order_id
                FROM public.orders
                GROUP BY order_id
                HAVING COUNT(*) > 1
            ) d
            """
        )
        return cur.fetchone()[0]


def assert_orders_no_duplicates(conn) -> None:
    """Проверяет, что в таблице нет дублей по order_id."""
    duplicates = fetch_orders_duplicates(conn)
    if duplicates:
        raise ValueError(f"Обнаружены дубли по order_id ({duplicates} шт.) — проверь загрузку данных.")
