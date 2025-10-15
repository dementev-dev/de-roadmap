from __future__ import annotations

import importlib
import sys
from pathlib import Path
from types import ModuleType
from typing import Type


PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.append(str(PROJECT_ROOT))

if "airflow" not in sys.modules:
    airflow_module = ModuleType("airflow")
    airflow_module.__path__ = [str(PROJECT_ROOT / "airflow")]
    sys.modules["airflow"] = airflow_module

    providers_module = ModuleType("airflow.providers")
    providers_module.__path__ = []
    sys.modules["airflow.providers"] = providers_module
    airflow_module.providers = providers_module

    postgres_module = ModuleType("airflow.providers.postgres")
    postgres_module.__path__ = []
    sys.modules["airflow.providers.postgres"] = postgres_module
    providers_module.postgres = postgres_module

    hooks_module = ModuleType("airflow.providers.postgres.hooks")
    hooks_module.__path__ = []
    sys.modules["airflow.providers.postgres.hooks"] = hooks_module
    postgres_module.hooks = hooks_module

if "psycopg2" not in sys.modules:
    psycopg2_stub = ModuleType("psycopg2")
    psycopg2_stub.connect = lambda **_: None  # type: ignore[assignment]
    sys.modules["psycopg2"] = psycopg2_stub


def _ensure_stub_module(full_name: str) -> ModuleType:
    """
    Ensure that module placeholders exist for a dotted path and return leaf module.
    """
    parts = full_name.split(".")
    module: ModuleType | None = None
    path = ""
    for part in parts:
        path = f"{path}.{part}" if path else part
        if path not in sys.modules:
            new_module = ModuleType(path)
            if module is not None:
                setattr(module, part, new_module)
            sys.modules[path] = new_module
            module = new_module
        else:
            module = sys.modules[path]
    assert isinstance(module, ModuleType)
    return module


def patch_postgres_hook(monkeypatch, hook_cls: Type) -> None:
    """
    Patch PostgresHook so that helpers.greenplum can be exercised without real Airflow.
    """
    try:
        module = importlib.import_module("airflow.providers.postgres.hooks.postgres")
    except ModuleNotFoundError:
        module = _ensure_stub_module("airflow.providers.postgres.hooks.postgres")
    monkeypatch.setattr(module, "PostgresHook", hook_cls, raising=False)
