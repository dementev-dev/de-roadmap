# DE Starter Kit — Greenplum + Kafka + Airflow

Обновлено: 2025-09-15 11:12

Этот вариант повторяет логику Postgres-стенда, но в роли DWH — **Greenplum (single node в Docker)**.  
Airflow по‑прежнему использует **Postgres** только как metadata DB (это стандартная и простая схема).

## Требования
- Docker Desktop (Windows/Mac) или Docker Engine 24+ (Linux) с `docker compose v2`.
- Рекомендуемые среды: Linux, macOS, или Windows через WSL. Чистый Windows работает, но с ограничениями (пути/права, отсутствие `make` по умолчанию).
- Make (опционально). Если `make` нет — используйте команды `docker compose` из примеров ниже.
- Windows: в стандартный Git Bash `make` отсутствует. Для `make` используйте WSL/Chocolatey/Scoop/MSYS2; иначе работайте через `docker compose`.

## Что внутри
- **Greenplum** (single node) — `woblerr/greenplum:6.27.1` (локальный стенд для разработки).
- **Kafka (KRaft, без Zookeeper)** — генерация событий.
- **Airflow (2.9)** — оркестрация пайплайна, metadata в Postgres.
- **DAG** `kafka_to_greenplum.py` — генерирует данные → пишет в Kafka → читает и грузит в Greenplum.
- **DAG** `greenplum_data_quality.py` — выполняет проверки качества данных (наличие таблицы, схема, заполненность, дубли).
- **Kafka UI** — автоматически подключается к стендовому брокеру (bootstrap берётся из `KAFKA_BOOTSTRAP` или значения по умолчанию).
- **DDL** `sql/ddl_gp.sql` — создаёт колонночную таблицу `orders` без PRIMARY KEY (AO-таблицы GP6 не поддерживают его), распределённую по `order_id`; контроль дублей реализован в DAG.

> Примечание по версиям и надёжности: используется образ `woblerr/greenplum:6.27.1` с поддержкой переменных окружения и fallback значениями.

## Быстрый старт
Опционально установим `make` (если нужен):

- Linux (Debian/Ubuntu):
  ```bash
  sudo apt update && sudo apt install -y make
  ```
- macOS (Homebrew):
  ```bash
  brew install make
  ```
- Windows варианты:
  - WSL (Ubuntu): `sudo apt install -y make`
  - Chocolatey: `choco install make`
  - Scoop: `scoop install make`
  - MSYS2: `pacman -S make`

Настроим переменные окружения
```bash
cp .env.example .env
# При необходимости отредактируйте .env для ваших настроек
```

Запустим приложение (вариант с Make)
```bash
make up && make airflow-init
make logs   # ждем "Listening at: http://0.0.0.0:8080"
```
Открой Airflow: http://localhost:8080 (логин/пароль см. `.env`, по умолчанию admin/admin).  
Включи DAG **kafka_to_greenplum** и нажми **Trigger** — он создаст таблицу и загрузит ~1000 записей в `gpadmin.public.orders`.

Альтернатива без Make (на всех ОС):
```bash
docker compose -f docker-compose.yml up -d
docker compose -f docker-compose.yml run --rm airflow-init
docker compose -f docker-compose.yml logs -f airflow-webserver airflow-scheduler
```

### Создаём Airflow Connection для Greenplum
1. Открой Airflow UI → **Admin → Connections** → **Add a new record**.
2. Заполни поля:
   - `Conn Id`: `greenplum_conn` (или своё значение, тогда пропиши его в переменной `GP_CONN_ID`).
   - `Conn Type`: `Postgres`.
   - `Host`: `greenplum`.
   - `Schema`: значение `GP_DB` (по умолчанию `gpadmin`).
   - `Login`: `GP_USER` (по умолчанию `gpadmin`).
   - `Password`: `GP_PASSWORD`.
   - `Port`: `5432`.
3. Сохрани соединение и перезапусти DAG (если он уже был активирован).

CLI-альтернатива (выполняется внутри контейнера Airflow):
```bash
docker compose -f docker-compose.yml exec airflow-webserver bash -lc "
airflow connections add 'greenplum_conn' \
    --conn-type postgres \
    --conn-host greenplum \
    --conn-login ${GP_USER:-gpadmin} \
    --conn-password ${GP_PASSWORD:-gpadmin} \
    --conn-schema ${GP_DB:-gpadmin} \
    --conn-port 5432"
```

### Интерфейсы и порты
- Airflow UI: http://localhost:8080 (admin/admin по умолчанию)
- Kafka UI: http://localhost:8082 (просмотр топиков/сообщений; подключение к кластеру создаётся автоматически)
- Greenplum: `localhost:${GP_PORT:-5432}` (внешний порт проброшен из контейнера)
- Postgres (Airflow metadata): `localhost:5433`
- Kafka (для клиентов на хосте): `localhost:9092`
- Kafka (из контейнеров Docker): `kafka:29092`

### Параметры чтения/загрузки
- `KAFKA_BATCH_SIZE` — размер батча при вставке в Greenplum (по умолчанию 500).
- `KAFKA_POLL_TIMEOUT` — таймаут ожидания сообщения в секундах (по умолчанию 10).
- `KAFKA_MAX_EMPTY_POLLS` — сколько подряд пустых `poll` допускается перед выходом из цикла (по умолчанию 3).

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

### Проверка Kafka
- Открой Kafka UI: http://localhost:8082 — проверь, что существует топик `orders` и в нём появляются сообщения после запуска DAG.
- Если автосоздание топиков в брокере отключено, создай топик вручную через UI перед запуском DAG.

**Подключение К Greenplum**
- DBeaver (PostgreSQL/Greenplum драйвер):
  - Запусти DBeaver → Database → New Connection → выбери `Greenplum`.
  - Host: `localhost`
  - Port: `5432` (или значение из `GP_PORT`)
  - Database: `gpadmin` (или `GP_DB`)
  - Username: `gpadmin` (или `GP_USER`)
  - Password: `gpadmin` (или `GP_PASSWORD`)
  - SSL: Disabled (для локального стенда)
  - Нажми Test Connection → Finish.
- psql внутри контейнера (rootless доступ к встроенному psql):
  - Команда Make: `make gp-psql`
  - Или напрямую: `docker compose -f docker-compose.yml exec greenplum bash -c "su - gpadmin -c '/usr/local/greenplum-db/bin/psql -p 5432 -d gpadmin'"`
  - Примеры команд внутри psql: 
`\dt`, `SELECT version()`, `SELECT count(*) FROM public.orders;`

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
- `GP_CONN_ID` — ID Airflow Connection (по умолчанию: `greenplum_conn`)
- `GP_USE_AIRFLOW_CONN` — использовать ли Airflow Connection (`true`/`false`). Если `false`, DAG подключается к БД напрямую по ENV.

Настройки Kafka берутся из тех же переменных окружения:

- `KAFKA_BOOTSTRAP` — bootstrap-адрес брокера для Airflow и Kafka UI (по умолчанию `kafka:29092`).
- `KAFKA_TOPIC` — имя демо-топика (по умолчанию `orders`).
- `KAFKA_BATCH_SIZE`, `KAFKA_POLL_TIMEOUT`, `KAFKA_MAX_EMPTY_POLLS` — параметры чтения/загрузки (см. раздел выше).
- `KAFKA_UI_CLUSTER_NAME` — отображаемое имя кластера в Kafka UI (по умолчанию `KafkaCluster`).

Образ `woblerr/greenplum:6.27.1` использует переменные:
- `GREENPLUM_USER` (маппится на `GP_USER`)
- `GREENPLUM_PASSWORD` (маппится на `GP_PASSWORD`)
- `GREENPLUM_DATABASE_NAME` (маппится на `GP_DB`)

Внутри контейнеров Airflow хост для подключения к БД — `greenplum` (см. `GP_HOST`), а с вашей машины — `localhost:${GP_PORT}`. Созданный в Airflow Connection реиспользует те же значения, что и `.env`.

## Фиксация образов (pinning) и альтернативы
- Зафиксируй digest образа `woblerr/greenplum:6.27.1` (Docker Hub → Tag → «Copy digest») и замени тег на `@sha256:...` в `docker-compose.yml`.
- Альтернативы: можно использовать другие образы Greenplum или собрать собственный образ для GPDB 6/7.
- Особенность GPDB 6: в нём **нет** `INSERT ... ON CONFLICT`. В DAG используется безопасная для GP6 конструкция `INSERT ... WHERE NOT EXISTS` внутри транзакции.

## Ограничения и заметки
- Этот стенд — учебный. Для высокой надёжности и производительности Greenplum обычно разворачивают кластерами на нескольких узлах, на железе/VM с отдельными дисками под сегменты.
- Для GP7 (основан на новее PostgreSQL) можно упростить загрузку, включая `ON CONFLICT`. В учебных целях мы остались на широко доступном GP6 образе.

## Поток данных (DAG)
Последовательность задач в `kafka_to_greenplum`:
- `create_table` — создаёт таблицу `public.orders` в Greenplum (колоночная, AO/CO, распределение по `order_id`).
- `produce_messages` — генерирует ~1000 сообщений и пишет их в Kafka-топик `orders`.
- `consume_and_load` — читает сообщения из Kafka и вставляет в `public.orders` батчами (по `KAFKA_BATCH_SIZE`) с защитой от дублей для GP6 через anti-join. По умолчанию использует Airflow Connection `greenplum_conn`, но при `GP_USE_AIRFLOW_CONN=false` подключается по ENV (`GP_HOST`, `GP_PORT`, `GP_DB`, `GP_USER`, `GP_PASSWORD`).

Повторный запуск DAG безопасен: при вставке используется проверка на существование `order_id`.

## Типичные проблемы и решения
- Airflow UI не открывается: проверь `make logs` и дождись строки `Listening at: http://0.0.0.0:8080`.
- Ошибка подключения к Greenplum: дождись, пока контейнер `greenplum` станет `healthy`; проверь, что порт `GP_PORT` не занят локальными сервисами.
- Нет топика `orders`: создай его через Kafka UI (или перезапусти DAG после включения авто‑создания топиков).
- `make` отсутствует на Windows: используй команды `docker compose` из раздела «Альтернатива без Make» или установи Git Bash/WSL.

## Проверка данных
- Подними стенд (`make up && make airflow-init`) и запусти DAG `kafka_to_greenplum`, чтобы заполнить таблицу `orders`.
- Активируй и запусти DAG `greenplum_data_quality` — он последовательно проверит наличие таблицы, схему, объём данных и отсутствие дублей. Все проверки выполняются внутри Airflow и используют те же настройки подключений.
