from __future__ import annotations

import importlib

import pytest


def _airflow_available() -> bool:
    try:
        af = importlib.import_module("airflow")
    except Exception:
        return False
    # Real Airflow exposes DAG at top-level
    return hasattr(af, "DAG")


pytestmark = pytest.mark.skipif(not _airflow_available(), reason="Airflow is not installed for DAG smoke tests")


def _load_dag(module_name: str):
    mod = importlib.import_module(module_name)
    assert hasattr(mod, "dag"), f"{module_name} must expose variable 'dag'"
    return getattr(mod, "dag")


def test_csv_to_greenplum_dag_structure():
    dag = _load_dag("airflow.dags.csv_to_greenplum")

    # tasks
    expected_tasks = {
        "create_orders_table",
        "generate_csv",
        "preview_csv",
        "load_csv_to_greenplum",
    }
    assert expected_tasks.issubset(dag.task_dict.keys())

    # linear dependencies
    t1 = dag.get_task("create_orders_table")
    t2 = dag.get_task("generate_csv")
    t3 = dag.get_task("preview_csv")
    t4 = dag.get_task("load_csv_to_greenplum")

    assert t2 in t1.get_direct_relatives("downstream")
    assert t3 in t2.get_direct_relatives("downstream")
    assert t4 in t3.get_direct_relatives("downstream")


def test_data_quality_greenplum_dag_structure():
    dag = _load_dag("airflow.dags.data_quality_greenplum")

    expected_tasks = {
        "check_orders_table_exists",
        "check_orders_schema",
        "check_orders_has_rows",
        "check_order_duplicates",
        "data_quality_summary",
    }
    assert expected_tasks.issubset(dag.task_dict.keys())

    e = dag.get_task("check_orders_table_exists")
    s = dag.get_task("check_orders_schema")
    h = dag.get_task("check_orders_has_rows")
    d = dag.get_task("check_order_duplicates")
    q = dag.get_task("data_quality_summary")

    assert s in e.get_direct_relatives("downstream")
    assert h in s.get_direct_relatives("downstream")
    assert d in h.get_direct_relatives("downstream")
    assert q in d.get_direct_relatives("downstream")
