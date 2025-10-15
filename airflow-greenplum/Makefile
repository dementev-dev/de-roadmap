SHELL := /bin/bash
UV := uv
PYTHON_VERSION := 3.11

.PHONY: up down airflow-init logs gp-psql ddl-gp dev-setup dev-sync dev-lock test lint fmt clean-venv

up:
	docker compose -f docker-compose.yml up -d

down:
	docker compose -f docker-compose.yml down -v

airflow-init:
	docker compose -f docker-compose.yml run --rm airflow-init

logs:
	docker compose -f docker-compose.yml logs -f airflow-webserver airflow-scheduler

gp-psql:
	docker compose -f docker-compose.yml exec greenplum bash -c "su - gpadmin -c '/usr/local/greenplum-db/bin/psql -p 5432 -d gpadmin'"

ddl-gp:
	docker compose -f docker-compose.yml exec greenplum bash -c "su - gpadmin -c '/usr/local/greenplum-db/bin/psql -d gpadmin -f /sql/ddl_gp.sql'"

dev-setup:
	$(UV) python install $(PYTHON_VERSION)
	$(UV) python pin $(PYTHON_VERSION)
	$(UV) sync

dev-sync:
	$(UV) sync

dev-lock:
	$(UV) lock --upgrade

test:
	$(UV) run pytest -q

lint:
	$(UV) run black --check airflow tests
	$(UV) run isort --check-only airflow tests

fmt:
	$(UV) run black airflow tests
	$(UV) run isort airflow tests

clean-venv:
	python -c "import shutil; shutil.rmtree('.venv', ignore_errors=True)"
