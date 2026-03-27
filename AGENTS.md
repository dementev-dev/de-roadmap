# Repository Guidelines

## Project Structure & Module Organization
- Root `README.md` describes the learning roadmap (RU) and serves as the main page of the MkDocs site.
- `dwh-modeling/` contains the article and demo DWH model; SQL lives in `dwh-modeling/sql` as ordered scripts `01_...sql`–`09_...sql` (07–09 are homework DDL, template and solution).
- `postgres-bookings/` is a Dockerized PostgreSQL + demo “bookings” DB; start it first, then apply DWH scripts against the `demo` database.
- `mkdocs.yml` — MkDocs Material config; `docs_dir: .` (repo root = site root). Excluded dirs: `project/`, `postgres-bookings/`, `.github/`, `.claude/`.
- `.github/workflows/deploy-site.yml` — CI/CD: push to `main` → build → deploy to GitHub Pages.
- `project/` — PRD and ADR (excluded from site).

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

## Markdown Style (dual-compatible: GitHub + MkDocs Material)

All `.md` files MUST render correctly on both GitHub and the MkDocs Material site. Follow these rules:

**Headings:**
- `README.md` (root): start from `##` (H2). Do NOT use `#` (H1) — MkDocs uses H1 as page title, multiple H1s break the right-sidebar TOC.
- `dwh-modeling/*.md`: may use `#` (H1) since each file is a separate page on the site.

**Lists:**
- Always leave a **blank line before the first list item** after a paragraph, heading, or any non-list text. Python-Markdown (MkDocs) requires this; GitHub tolerates its absence but blank lines don't hurt.
- Use **4-space indentation** for nested lists (not 2-space). GitHub supports both, Python-Markdown requires 4.
- Example:
  ```markdown
  Some introductory text:

  - Item one
  - Item two
      - Nested item (4 spaces)
  ```

**Links:**
- Internal links: always use **relative paths to `.md` files**: `[text](dwh-modeling/SCD.md)`. MkDocs resolves them automatically.
- Anchor links: use lowercase slugs with single hyphens. Avoid em-dash `—` in headings (it produces `--` in MkDocs slugs vs `-` on GitHub). Use commas or colons instead.

**Special characters in headings:**
- OK: colons `:`, commas `,`, parentheses `()`, guillemets `«»` — stripped equally by both platforms.
- Avoid: em-dash `—`, en-dash `–` — slug behavior differs between GitHub and MkDocs.

## MkDocs Site Commands
- Local preview (user starts, ask user to run via `!`):
  `uv run --with 'mkdocs-material==9.6.14' --with 'mkdocs-same-dir==0.1.3' mkdocs serve`
- Build with strict validation (catches broken links/anchors):
  `uv run --with 'mkdocs-material==9.6.14' --with 'mkdocs-same-dir==0.1.3' mkdocs build --strict`
- Visual check via Playwright (when `mkdocs serve` is running on port 8000):
  `npx playwright screenshot --viewport-size='1280,800' 'http://127.0.0.1:8000/#anchor' /path/to/screenshot.png`
  Then read the screenshot with the Read tool to inspect rendering. Use `--viewport-size='1280,2000'` for tall pages.
- Kill stuck dev server: `lsof -ti :8000 | xargs kill`
- Site URL: `https://dementev-dev.github.io/de-roadmap/`

## Testing Guidelines
- There is no dedicated test framework; treat SQL scripts as executable documentation.
- For `dwh-modeling/sql`, run scripts sequentially and rerun `04_validation.sql` after changes to ensure the demo model still loads and basic checks pass.
- For `postgres-bookings`, after modifications run `docker compose up -d && ./psql_sh` and verify simple queries such as `SELECT COUNT(*) FROM bookings.flights;`.

## Commit & Pull Request Guidelines

**Required:** Read [COMMIT_RULES.md](COMMIT_RULES.md) before making commits.

Pull requests should focus on one topic, include a brief context, list of changes, and manual steps to reproduce or validate (commands you ran, expected results).

## Security & Configuration Tips
- Do not commit personal `.env` files or credentials; use local overrides only.
- Demo credentials and ports in `postgres-bookings` are for local training only—never reuse them in shared or production environments.

