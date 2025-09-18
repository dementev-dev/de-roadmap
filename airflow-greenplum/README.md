# DE Starter Kit — Greenplum + Kafka + Airflow

Обновлено: 2025-09-15 11:12

Этот вариант повторяет логику Postgres-стенда, но в роли DWH — **Greenplum (single node в Docker)**.  
Airflow по‑прежнему использует **Postgres** только как metadata DB (это стандартная и простая схема).

## Что внутри
- **Greenplum** (single node) — `woblerr/greenplum:6.27.1` (локальный стенд для разработки).
- **Kafka (KRaft, без Zookeeper)** — генерация событий.
- **Airflow (2.9)** — оркестрация пайплайна, metadata в Postgres.
- **DAG** `kafka_to_greenplum.py` — генерирует данные → пишет в Kafka → читает и грузит в Greenplum.
- **DDL** `sql/ddl_gp.sql` — создаёт таблицу `orders` с распределением по `order_id`.

> Примечание по версиям и надёжности: используется образ `woblerr/greenplum:6.27.1` с поддержкой переменных окружения и fallback значениями. Для продакшен‑подобных тестов зафиксируй digest (SHA256) конкретного тега на Docker Hub.

## Быстрый старт
Установим make под Вашу операционную систему
```bash
sudo apt install -y make
```

Настроим переменные окружения
```bash
cp .env.example .env
# При необходимости отредактируйте .env для ваших настроек
```

Запустим приложение
```bash
make up && make airflow-init
make logs   # ждем "Listening at: http://0.0.0.0:8080"
```
Открой Airflow: http://localhost:8080 (логин/пароль см. `.env`, по умолчанию admin/admin).  
Включи DAG **kafka_to_greenplum** и нажми **Trigger** — он создаст таблицу и загрузит ~1000 записей в `gpadmin.public.orders`.

### Проверка загрузки
```bash
# Подключение к Greenplum через внешний psql клиент
psql -h localhost -p 5432 -U gpadmin -d gpadmin

# Или через Docker (используя make команду)
make gp-psql

# Или напрямую через Docker
docker compose -f docker-compose.yml exec greenplum bash -c "su - gpadmin -c '/usr/local/greenplum-db/bin/psql -p 5432 -d gpadmin'"

# Внутри psql:
\dt
SELECT count(*) FROM public.orders;
```

## Файлы
- `docker-compose.yml` — сервисы Greenplum + Kafka + Airflow + Postgres (metadata).
- `.env.example` — шаблон переменных окружения.
- `.env` — переменные окружения (создается из .env.example).
- `airflow/dags/kafka_to_greenplum.py` — сам DAG.
- `sql/ddl_gp.sql` — DDL таблицы в Greenplum.
- `Makefile` — обёртки команд (`up`, `down`, `airflow-init`, `gp-psql`, `ddl-gp`).

## Конфигурация через переменные окружения
Все настройки Greenplum передаются через переменные окружения в файле `.env` с fallback значениями:

- `GP_USER` — пользователь Greenplum (по умолчанию: gpadmin)
- `GP_PASSWORD` — пароль пользователя (по умолчанию: gpadmin)
- `GP_DB` — база данных (по умолчанию: gpadmin)
- `GP_PORT` — порт для подключения (по умолчанию: 5432)

Образ `woblerr/greenplum:6.27.1` использует переменные:
- `GREENPLUM_USER` (маппится на `GP_USER`)
- `GREENPLUM_PASSWORD` (маппится на `GP_PASSWORD`)
- `GREENPLUM_DATABASE_NAME` (маппится на `GP_DB`)

## Пинning и альтернативы
- Зафиксируй digest образа `woblerr/greenplum:6.27.1` (Docker Hub → Tag → «Copy digest») и замени тег на `@sha256:...` в `docker-compose.yml`.
- Альтернативы: можно использовать другие образы Greenplum или собрать собственный образ для GPDB 6/7.
- Особенность GPDB 6: в нём **нет** `INSERT ... ON CONFLICT`. В DAG используется безопасная для GP6 конструкция `INSERT ... WHERE NOT EXISTS` внутри транзакции.

## Ограничения и заметки
- Этот стенд — учебный. Для высокой надёжности и производительности Greenplum обычно разворачивают кластерами на нескольких узлах, на裸‑железе/VM с отдельными дисками под сегменты.
- Для GP7 (основан на новее PostgreSQL) можно упростить загрузку, включая `ON CONFLICT`. В учебных целях мы остались на широко доступном GP6 образе.
