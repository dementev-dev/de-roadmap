SHELL := /bin/bash

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
