# Commit Rules

Unified commit style for all project contributors. Follows [Conventional Commits](https://www.conventionalcommits.org/) specification.

## Language

- **Primary language**: Russian
- If language is not specified, use Russian
- For AI-generated commits, Russian is mandatory unless task explicitly sets `lang:en`
- English is allowed only by explicit instruction (`lang:en`) or external collaboration requirements
- Do not mix languages in free-text parts of one commit message (subject + body + footer)
- Conventional Commit `type(scope)` stays in English
- Technical terms (PostgreSQL, SQL, DWH, DDL, DML) keep as-is

## Header Format

```
<type>(<scope>): <short description>
```

- Maximum header length: 72 characters
- For Russian subject, use result form (e.g. "добавлено", "исправлено", "обновлено")
- For English subject, use imperative present form (e.g. "add", "fix", "update")
- For English subject, do not use past forms (e.g. "added", "fixed", "updated")
- No trailing period
- Keep subject specific; avoid vague messages like "update", "fix bug", "changes"

### Allowed `type`

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code restructuring without behavior change |
| `docs` | Documentation only |
| `test` | Tests, checks, validations |
| `chore` | Maintenance (configs, scripts, hooks) |
| `ci` | CI/CD changes |
| `perf` | Performance optimization |
| `revert` | Revert previous commit |

### Recommended `scope` for this repo

| Scope | Used for |
|-------|----------|
| `sql` | SQL scripts in `dwh-modeling/sql/` |
| `modeling` | DWH modeling docs, articles, schemas in `dwh-modeling/` |
| `bookings` | Docker PostgreSQL demo in `postgres-bookings/` |
| `docs` | Documentation, README, guides |
| `data` | Data files (CSV, fixtures) |

## Body Structure

For non-trivial changes, body is required. Use bullet points for readability.

Body is considered required when at least one condition is true:
- behavior or API/contract changed
- migration, rollback risk, or compatibility impact exists
- more than one meaningful file/module changed
- fix is non-obvious from header alone

### Multiline body in CLI (important)

- Do not pass body as one quoted string with `\n` (it will be stored literally).
- Use multiple `-m` flags, or `-F` with heredoc.

Correct:

```bash
git commit \
  -m "feat(sql): добавлена валидация данных для DWH" \
  -m "- Зачем:
  - нужна проверка целостности перед загрузкой
- Что:
  - добавлен скрипт 04_validation.sql
  - добавлены проверки на NULL и уникальность
- Проверка:
  - psql -f dwh-modeling/sql/04_validation.sql"
```

Also correct:

```bash
git commit -F- <<'MSG'
feat(sql): добавлена валидация данных для DWH

- Зачем:
  - нужна проверка целостности перед загрузкой
- Что:
  - добавлен скрипт 04_validation.sql
  - добавлены проверки на NULL и уникальность
- Проверка:
  - psql -f dwh-modeling/sql/04_validation.sql
MSG
```

### Template (Russian - default)

```
<type>(<scope>): <краткое описание результата>

- Зачем:
  - причина изменения
- Что:
  - ключевое изменение 1
  - ключевое изменение 2
- Проверка:
  - как проверено
```

### Template (English - only with `lang:en`)

```
<type>(<scope>): <short action description>

- Why:
  - reason for change
- What:
  - key change 1
  - key change 2
- Check:
  - how verified (command/test/smoke-check)
```

## Commit Scope Rules

- One commit = one logical task
- Don't mix feature changes with large refactoring
- Update docs in the same commit where behavior changes

## Breaking Changes

Use `!` in header for breaking changes:
```
feat(sql)!: rename stg_orders column contract
```

Add footer:
```
BREAKING CHANGE: column order_date renamed to created_at
```

## Examples

### Good examples

```
feat(sql): добавлен скрипт загрузки DM-слоя

- Зачем:
  - нужны витрины для аналитики
- Что:
  - добавлен 06_dml_dm.sql с загрузкой фактов и измерений
  - добавлены индексы для оптимизации запросов
- Проверка:
  - psql -f dwh-modeling/sql/06_dml_dm.sql
  - SELECT COUNT(*) FROM dm.fact_orders;
```

```
fix(bookings): исправлен порт в docker-compose.yml

- Зачем:
  - конфликт с локальным PostgreSQL на 5432
- Что:
  - порт хоста изменен на 5433
- Проверка:
  - docker compose up -d
  - psql -h localhost -p 5433 -U postgres
```

```
docs(modeling): обновлена схема Data Vault после ревью
```

```
chore(docs): синхронизировано оглавление README
```

### Bad examples (don't do this)

```
❌ added sql script               # no type, past tense
❌ feat: добавлен скрипт          # no scope
❌ fix: исправлен баг             # no scope, vague and non-actionable
❌ feat(sql): added new table     # past tense in English subject
❌ feat(sql): add script and fix validation and update docs  # multiple concerns
❌ feat(docs): add README и почини SQL # mixed languages in one message
```

## Quick Reference

```bash
# Feature
feat(scope): добавлена новая возможность

# Bug fix
fix(scope): исправлена проблема

# Documentation
docs(scope): обновлена документация

# Refactoring
refactor(scope): упрощена структура без изменения поведения

# Performance
perf(scope): ускорено выполнение

# Maintenance
chore(scope): обновлены служебные настройки

# Feature (lang:en)
feat(scope): add new capability

# Bug fix (lang:en)
fix(scope): correct response parsing

# Documentation (lang:en)
docs(scope): update setup guide
```
