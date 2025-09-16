# DE Starter Kit — Greenplum + Kafka + Airflow

Обновлено: 2025-09-15 11:12

Этот вариант повторяет логику Postgres-стенда, но в роли DWH — **Greenplum (single node в Docker)**.  
Airflow по‑прежнему использует **Postgres** только как metadata DB (это стандартная и простая схема).

## Что внутри
- **Greenplum** (single node) — `datagrip/greenplum:6.8` (локальный стенд для разработки).
- **Kafka (KRaft, без Zookeeper)** — генерация событий.
- **Airflow (2.9)** — оркестрация пайплайна, metadata в Postgres.
- **DAG** `kafka_to_greenplum.py` — генерирует данные → пишет в Kafka → читает и грузит в Greenplum.
- **DDL** `sql/ddl_gp.sql` — создаёт таблицу `orders` с распределением по `order_id`.

> Примечание по версиям и надёжности: образы Greenplum в публичном Docker Hub — комьюнити/сторонние. Я выбрал `datagrip/greenplum:6.8` как популярный и поддерживаемый для локальной разработки. Для продакшен‑подобных тестов зафиксируй digest (SHA256) конкретного тега на Docker Hub и/или собери образ самостоятельно. См. раздел «Пинning и альтернативы» ниже.

## Быстрый старт
Установим make под Вашу операционную систему
```bash
sudo apt install -y make
```
Запустим приложение
```bash
cp .env.example .env
make up && make airflow-init
make logs   # ждем "Listening at: http://0.0.0.0:8080"
```
Открой Airflow: http://localhost:8080 (логин/пароль см. `.env`, по умолчанию admin/admin).  
Включи DAG **kafka_to_greenplum** и нажми **Trigger** — он создаст таблицу и загрузит ~1000 записей в `gpadmin.public.orders`.

### Проверка загрузки
```bash
make gp-psql     # войти в psql к Greenplum
-- внутри psql:
\dt
SELECT count(*) FROM public.orders;
```

## Файлы
- `docker-compose.gp.yml` — сервисы Greenplum + Kafka + Airflow + Postgres (metadata).
- `.env.example` — переменные окружения.
- `airflow/dags/kafka_to_greenplum.py` — сам DAG.
- `sql/ddl_gp.sql` — DDL таблицы в Greenplum.
- `Makefile` — обёртки команд (`up`, `down`, `airflow-init`, `gp-psql`, `ddl-gp`).

## Пинning и альтернативы
- Зафиксируй digest образа `datagrip/greenplum:6.8` (Docker Hub → Tag → «Copy digest») и замени тег на `@sha256:...` в `docker-compose.gp.yml`.
- Альтернативы: репозиторий `woblerr/docker-greenplum` позволяет **собрать свой образ** для GPDB 6/7 (подойдёт, если нужен полный контроль и повторяемость сборки).
- Особенность GPDB 6: в нём **нет** `INSERT ... ON CONFLICT`. В DAG используется безопасная для GP6 конструкция `INSERT ... WHERE NOT EXISTS` внутри транзакции.

## Ограничения и заметки
- Этот стенд — учебный. Для высокой надёжности и производительности Greenplum обычно разворачивают кластерами на нескольких узлах, на裸‑железе/VM с отдельными дисками под сегменты.
- Для GP7 (основан на новее PostgreSQL) можно упростить загрузку, включая `ON CONFLICT`. В учебных целях мы остались на широко доступном GP6 образе.
