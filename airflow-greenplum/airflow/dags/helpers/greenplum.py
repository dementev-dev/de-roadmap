from __future__ import annotations

import logging
import os
from typing import List, Sequence, Tuple

import psycopg2

# Настройки для подключения к Greenplum. По умолчанию используем Airflow Connection,
# но при проблемах можно переключиться на ENV-подключение, установив GP_USE_AIRFLOW_CONN=false.
GP_CONN_ID = os.getenv("GP_CONN_ID", "greenplum_conn")
GP_USE_AIRFLOW_CONN = os.getenv("GP_USE_AIRFLOW_CONN", "true").lower() in ("1", "true", "yes")

# Ожидаемая схема таблицы orders для проверки качества данных
EXPECTED_ORDERS_SCHEMA: List[Tuple[str, str]] = [
    ("order_id", "bigint"),
    ("order_ts", "timestamp without time zone"),
    ("customer_id", "bigint"),
    ("amount", "numeric"),
]


def get_gp_conn():
    """
    Возвращает psycopg2 connection к Greenplum.
    
    Приоритет подключения:
    1. Через Airflow Connection (если настроено и доступно)
    2. Прямое подключение по переменным окружения (фоллбек)
    
    Returns:
        psycopg2 connection object
    """
    if GP_USE_AIRFLOW_CONN:
        try:
            from airflow.providers.postgres.hooks.postgres import PostgresHook

            hook = PostgresHook(postgres_conn_id=GP_CONN_ID)
            conn = hook.get_conn()
            logging.info("✅ Подключение через Airflow Connection успешно")
            return conn
        except Exception as e:
            logging.warning("⚠️ Не удалось подключиться через Airflow Connection: %s", e)
            logging.info("🔄 Переключаемся на прямое подключение по ENV переменным")
            # Фоллбек на прямое подключение по переменным окружения.

    # Прямое подключение по переменным окружения
    conn_params = {
        "dbname": os.getenv("GP_DB", "gpadmin"),
        "user": os.getenv("GP_USER", "gpadmin"),
        "password": os.getenv("GP_PASSWORD", ""),
        "host": os.getenv("GP_HOST", "greenplum"),
        "port": int(os.getenv("GP_PORT", "5432")),
    }
    logging.info("🔗 Подключение к Greenplum: %s:%s", conn_params["host"], conn_params["port"])
    return psycopg2.connect(**conn_params)


def assert_orders_table_exists(conn) -> None:
    """
    Проверяет наличие таблицы orders в схеме public.
    
    Args:
        conn: Подключение к Greenplum
        
    Raises:
        ValueError: Если таблица не найдена
    """
    logging.info("🔍 Проверяем существование таблицы public.orders...")
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT 1
            FROM pg_catalog.pg_tables
            WHERE schemaname = 'public' AND tablename = 'orders'
            """
        )
        if cur.fetchone() is None:
            raise ValueError("❌ Таблица public.orders не найдена; запусти DAG csv_to_greenplum.")
    logging.info("✅ Таблица public.orders существует")


def fetch_orders_schema(conn) -> Sequence[Tuple[str, str]]:
    """
    Получает схему таблицы orders из information_schema.
    
    Args:
        conn: Подключение к Greenplum
        
    Returns:
        Список кортежей (имя_колонки, тип_данных)
    """
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
    """
    Проверяет, что схема таблицы orders соответствует ожидаемой.
    
    Args:
        conn: Подключение к Greenplum
        
    Raises:
        ValueError: Если схема не соответствует ожидаемой
    """
    logging.info("📋 Проверяем схему таблицы orders...")
    schema = fetch_orders_schema(conn)
    logging.info("📊 Фактическая схема: %s", list(schema))
    logging.info("📊 Ожидаемая схема: %s", EXPECTED_ORDERS_SCHEMA)
    
    if list(schema) != EXPECTED_ORDERS_SCHEMA:
        raise ValueError(f"❌ Неожиданная схема orders: {schema}. Ожидали {EXPECTED_ORDERS_SCHEMA}.")
    logging.info("✅ Схема таблицы orders соответствует ожиданиям")


def fetch_orders_count(conn) -> int:
    """
    Получает количество строк в таблице orders.
    
    Args:
        conn: Подключение к Greenplum
        
    Returns:
        Количество строк в таблице
    """
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM public.orders")
        return cur.fetchone()[0]


def assert_orders_have_rows(conn) -> None:
    """
    Проверяет, что таблица orders не пустая.
    
    Args:
        conn: Подключение к Greenplum
        
    Raises:
        ValueError: Если таблица пустая
    """
    logging.info("📊 Проверяем наличие данных в таблице orders...")
    row_count = fetch_orders_count(conn)
    logging.info("📈 Количество строк в orders: %s", row_count)
    
    if row_count <= 0:
        raise ValueError("❌ Таблица public.orders пустая — запусти DAG csv_to_greenplum перед проверкой.")
    logging.info("✅ Таблица orders содержит данные (%s строк)", row_count)


def fetch_orders_duplicates(conn) -> int:
    """
    Подсчитывает количество дубликатов по order_id.
    
    Args:
        conn: Подключение к Greenplum
        
    Returns:
        Количество дублирующихся order_id
    """
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
    """
    Проверяет, что в таблице нет дублей по order_id.
    
    Args:
        conn: Подключение к Greenplum
        
    Raises:
        ValueError: Если обнаружены дубликаты
    """
    logging.info("🔍 Проверяем отсутствие дубликатов по order_id...")
    duplicates = fetch_orders_duplicates(conn)
    logging.info("📊 Найдено дубликатов: %s", duplicates)
    
    if duplicates:
        raise ValueError(f"❌ Обнаружены дубли по order_id ({duplicates} шт.) — проверь загрузку данных.")
    logging.info("✅ Дубликаты не обнаружены")
