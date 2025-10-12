# Repository Guidelines

## Project Structure & Module Organization
- `airflow/dags/` — Airflow DAGs (e.g., `airflow/dags/kafka_to_greenplum.py`).
- `airflow/requirements.txt` — Python deps installed inside Airflow containers.
- `sql/` — database DDL and helpers (e.g., `sql/ddl_gp.sql`).
- `docker-compose.yml` — Greenplum, Kafka, Airflow, Postgres (metadata DB).
- `Makefile` — local DX commands; see targets below.
- `.env(.example)` — runtime configuration; never commit real secrets.

## Build, Test, and Development Commands
- `make up` — start the full stack.
- `make airflow-init` — migrate metadata DB and create admin user.
- `make logs` — follow webserver and scheduler logs.
- `make ddl-gp` — apply DDL to Greenplum.
- `make gp-psql` — open `psql` in the GP container.
- `make down` — stop stack and remove volumes.
Example: `make up && make airflow-init` then open `http://localhost:8080`.

## Coding Style & Naming Conventions
- Python: PEP 8, 4-space indents, `snake_case` for functions/vars, DAG IDs lower_snake_case.
- Imports: stdlib → third-party → local; prefer one module per line.
- SQL: uppercase keywords, `snake_case` identifiers, end statements with `;`.
- Filenames: DAGs as `<source>_to_<target>.py` (e.g., `kafka_to_greenplum.py`).
- Formatting: if available, use `black` (88 cols) and `isort`; otherwise keep existing style.
- Language: комментарии, docstrings и документацию (README, описания PR/Issues) пишем на русском; имена идентификаторов и код — на английском.

## Testing Guidelines
- No test suite yet. If adding tests, use `pytest` under `tests/` with `test_*.py`.
- Prefer unit tests for Python callables used by tasks; mock env vars and external systems.
- Run locally with `pytest -q`.

## Commit & Pull Request Guidelines
- Use Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:` etc. Example: `feat(dags): load orders to Greenplum`.
- Keep PRs focused; include a description, run steps, and relevant screenshots (e.g., DAG graph or task logs).
- Link issues; update `README.md` and DDL when behavior or schema changes.

## Security & Configuration Tips
- Configure via `.env`; do not hardcode credentials. Common vars: `GP_USER`, `GP_PASSWORD`, `GP_DB`, `GP_PORT`, `PG_*`, `AIRFLOW_*`.
- Be cautious with `make down` (removes volumes). Pin images/deps; prefer digests for critical images.

## Agent-Specific Notes
- Keep changes minimal and localized; do not rename Make targets without updating docs.
- Validate by running `make up`, `make airflow-init`, and inspecting the DAG in Airflow.
