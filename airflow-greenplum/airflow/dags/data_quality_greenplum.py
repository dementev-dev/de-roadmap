from __future__ import annotations

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
    """Оборачиваем проверку в контекст подключения."""
    with get_gp_conn() as conn:
        check_callable(conn)


default_args = {"owner": "airflow", "retries": 1, "retry_delay": timedelta(seconds=30)}

with DAG(
    dag_id="greenplum_data_quality",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    default_args=default_args,
    tags=["demo", "greenplum", "quality"],
) as dag:
    check_exists = PythonOperator(
        task_id="check_orders_table_exists",
        python_callable=_run_check,
        op_args=[assert_orders_table_exists],
    )
    check_schema = PythonOperator(
        task_id="check_orders_schema",
        python_callable=_run_check,
        op_args=[assert_orders_schema],
    )
    check_has_rows = PythonOperator(
        task_id="check_orders_has_rows",
        python_callable=_run_check,
        op_args=[assert_orders_have_rows],
    )
    check_no_duplicates = PythonOperator(
        task_id="check_order_duplicates",
        python_callable=_run_check,
        op_args=[assert_orders_no_duplicates],
    )

    check_exists >> check_schema >> check_has_rows >> check_no_duplicates
