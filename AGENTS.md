# Repository Guidelines

## Project Structure & Module Organization
- Root `README.md` describes the learning roadmap (RU).
- `dwh-modeling/` contains the article and demo DWH model; SQL lives in `dwh-modeling/sql` as ordered scripts `01_...sql`–`06_...sql`.
- `postgres-bookings/` is a Dockerized PostgreSQL + demo “bookings” DB; start it first, then apply DWH scripts against the `demo` database.

## Build, Test, and Development Commands
- Start demo Postgres:  
  `cd postgres-bookings && bash download_db.sh && docker compose up -d`
- Open `psql` inside the container:  
  `cd postgres-bookings && ./psql_sh`
- Apply DWH schema from the repo root (after Postgres is up):  
  `psql -h 127.0.0.1 -p 5432 -U postgres -d demo -f dwh-modeling/sql/01_ddl_stg-dds.sql`
- Stop and reset the cluster when needed:  
  `cd postgres-bookings && docker compose down -v`

## Coding Style & Naming Conventions
- SQL: PostgreSQL dialect, uppercase keywords, `snake_case` identifiers, 4-space indentation, and concise comments (`-- ...`).
- SQL files: keep numeric prefixes (`01_`, `02_`, …) to reflect execution order and use descriptive suffixes like `ddl_*` / `dml_*`.
- Shell: target `bash`, prefer simple, POSIX-friendly constructs; mirror the style of existing scripts in `postgres-bookings/`.

## Testing Guidelines
- There is no dedicated test framework; treat SQL scripts as executable documentation.
- For `dwh-modeling/sql`, run scripts sequentially and rerun `04_validation.sql` after changes to ensure the demo model still loads and basic checks pass.
- For `postgres-bookings`, after modifications run `docker compose up -d && ./psql_sh` and verify simple queries such as `SELECT COUNT(*) FROM bookings.flights;`.

## Commit & Pull Request Guidelines
- Commit messages are short, imperative or descriptive phrases (often in Russian), e.g. `Добавлено оглавление`, `Переработка структуры`; group related edits into a single commit.
- Pull requests should focus on one topic, include a brief context, list of changes, and manual steps to reproduce or validate (commands you ran, expected results).

## Security & Configuration Tips
- Do not commit personal `.env` files or credentials; use local overrides only.
- Demo credentials and ports in `postgres-bookings` are for local training only—never reuse them in shared or production environments.

