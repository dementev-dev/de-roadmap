from __future__ import annotations

import logging
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator

from helpers.greenplum import (
    assert_orders_have_rows,
    assert_orders_no_duplicates,
    assert_orders_schema,
    assert_orders_table_exists,
    get_gp_conn,
)


def _run_check(check_callable):
    """
    Оборачивает проверку качества данных в контекст подключения к Greenplum.
    
    Этот DAG предназначен для автоматической проверки качества данных в таблице orders:
    1. Проверяет существование таблицы
    2. Проверяет соответствие схемы
    3. Проверяет наличие данных
    4. Проверяет отсутствие дубликатов
    
    Args:
        check_callable: Функция проверки, принимающая подключение к БД
    """
    # Получаем имя функции для логов
    check_name = check_callable.__name__.replace("assert_", "")
    logging.info("🚀 Запуск проверки: %s", check_name)
    
    with get_gp_conn() as conn:
        check_callable(conn)
    
    logging.info("✅ Проверка пройдена: %s", check_name)


def _log_dq_summary():
    """
    Логирует итоговую сводку по качеству данных.
    Эта задача выполняется после всех проверок и показывает общий результат.
    """
    logging.info("🎉 Все проверки качества данных пройдены успешно!")
    logging.info("📊 Качество данных в таблице orders соответствует требованиям.")


default_args = {"owner": "airflow", "retries": 1, "retry_delay": timedelta(seconds=30)}

with DAG(
    dag_id="greenplum_data_quality",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    default_args=default_args,
    tags=["demo", "greenplum", "quality"],
    description="Автоматизированные проверки качества данных в Greenplum",
) as dag:
    # Задача 1: Проверка существования таблицы
    check_exists = PythonOperator(
        task_id="check_orders_table_exists",
        python_callable=_run_check,
        op_args=[assert_orders_table_exists],
    )
    
    # Задача 2: Проверка соответствия схемы таблицы
    check_schema = PythonOperator(
        task_id="check_orders_schema",
        python_callable=_run_check,
        op_args=[assert_orders_schema],
    )
    
    # Задача 3: Проверка наличия данных
    check_has_rows = PythonOperator(
        task_id="check_orders_has_rows",
        python_callable=_run_check,
        op_args=[assert_orders_have_rows],
    )
    
    # Задача 4: Проверка отсутствия дубликатов
    check_no_duplicates = PythonOperator(
        task_id="check_order_duplicates",
        python_callable=_run_check,
        op_args=[assert_orders_no_duplicates],
    )
    
    # Задача 5: Итоговая сводка
    dq_summary = PythonOperator(
        task_id="data_quality_summary",
        python_callable=_log_dq_summary,
    )

    # Определяем последовательность выполнения задач
    check_exists >> check_schema >> check_has_rows >> check_no_duplicates >> dq_summary
