# DE Starter Kit — Airflow + Greenplum + CSV

Добро пожаловать в учебный стенд для изучения основ Data Engineering! Этот проект поможет вам освоить ключевые инструменты современных data pipeline: **Airflow** для оркестрации, **pandas/CSV** для подготовки данных и **Greenplum** как аналитическую базу данных.

## 🎯 Что вы узнаете

- Как настроить локальный стек данных с помощью Docker
- Как Airflow управляет workflow и координирует задачи
- Как генерировать датасеты через pandas и сохранять их в CSV
- Как загружать данные в Greenplum пакетами и избегать дублей
- Как проверять качество данных в автоматизированных pipeline
- Основы проектирования ETL/ELT процессов

## 👩‍🎓 Для студентов (10‑минутный чек‑лист)

- Установите Docker Desktop и Git.
- Скопируйте настройки: `cp .env.example .env`.
- Поднимите стенд: `docker compose up -d` и инициализируйте Airflow: `docker compose run --rm airflow-init`.
- Откройте UI: http://localhost:8080 (admin/admin).
- Включите и запустите DAG `csv_to_greenplum`. Дождитесь Success.
- Проверьте данные: `make gp-psql` → `SELECT COUNT(*) FROM public.orders;`.
- Дополнительно: запустите `greenplum_data_quality` — все проверки должны быть зелёные.

Если что‑то не работает — смотрите «Типичные проблемы» и «Быстрый reset» ниже.

## Локальное окружение разработчика

Локальным окружением управляет [uv](https://docs.astral.sh/uv/) — он скачивает нужный Python и создаёт `.venv` на основе `pyproject.toml` / `uv.lock`.

```bash
uv sync
```

`uv sync` сам подтянет версию Python из `.python-version`/`pyproject.toml`, создаст `.venv` и установит зависимости. Для тех же действий можно использовать `make dev-sync`. Цель `make dev-setup` (или вручную `uv python install` + `uv python pin`) нужна только когда вы меняете версию Python или прогреваете кэш.

> Если требуется «классическое» активированное окружение, после `uv sync` выполните `.\.venv\Scripts\Activate.ps1` в PowerShell или `source .venv/bin/activate` в Unix-терминале.

Проверки и форматирование выполняем через uv:

```bash
make test            # uv run pytest -q
make lint            # black/isort в режиме проверки
make fmt             # автоформатирование black + isort
```

### Быстрый старт с uv

```bash
uv sync
uv run pytest -q
uv run black --check airflow tests
```

> Не устанавливайте пакеты напрямую через `pip install --user ...`. Если что-то уже попало в user-site, удалите `pip uninstall <package>` и проверьте `pip list --user`.
---

## 🚀 Быстрый старт (для новичков)

### Шаг 1: Подготовка окружения

**Требования:**
- Docker Desktop (Windows/Mac) или Docker Engine 24+ (Linux)
- Git для клонирования репозитория

> 💡 **Совет:** Если у вас Windows, рекомендуем использовать WSL (Windows Subsystem for Linux) для лучшей совместимости.

### Шаг 2: Настройка проекта

```bash
# Скопируйте файл настроек
cp .env.example .env

# Запустите стек (это может занять 2-3 минуты при первом запуске)
docker compose up -d

# Инициализируйте Airflow
docker compose run --rm airflow-init
```

### Шаг 3: Первый запуск pipeline

1. Откройте Airflow UI: **http://localhost:8080** (логин/пароль: admin/admin)
2. Найдите DAG с названием **csv_to_greenplum**
3. Нажмите на переключатель слева от названия DAG, чтобы включить его
4. Нажмите кнопку **Trigger** (значок воспроизведения ▶️)

🎉 **Поздравляем!** Вы только что запустили свой первый data pipeline:
- Система сгенерировала 1000 тестовых заказов при помощи pandas
- Датасет сохранился в CSV-файл в каталоге `./data`
- Airflow загрузил данные из CSV в Greenplum без дублей по `order_id`

### Шаг 4: Проверка результатов

**Проверка вручную:**
```bash
# Подключитесь к Greenplum и проверьте данные
docker compose exec greenplum bash -c "su - gpadmin -c 'psql -p 5432 -d gpadmin'"

# Внутри psql выполните:
\dt                    # Показать таблицы
SELECT count(*) FROM public.orders;  # Посчитать записи

# Посмотреть несколько строк
SELECT * FROM public.orders LIMIT 5;
```

CSV-файлы после выполнения DAG остаются в директории `./data`. Их можно открыть любым редактором или изучить через pandas.

### Быстрый reset

Если после изменений что‑то «сломалось»:

```bash
make down                 # Остановить и стереть данные в контейнерах
make up && make airflow-init
```

Это помогает, когда Greenplum не стартует из‑за «грязной» остановки и внутренних файлов.

---

## 🛠️ Подробная настройка (для уверенных пользователей)

### Установка Make (опционально)

Для удобства работы с проектом рекомендуем установить `make`:

- **Linux (Debian/Ubuntu):** `sudo apt install -y make`
- **macOS:** `brew install make`
- **Windows:** 
  - WSL: `sudo apt install -y make`
  - Chocolatey: `choco install make`
  - Scoop: `scoop install make`

С `make` команды становятся короче:
```bash
make up && make airflow-init    # Запуск стека
make logs                       # Просмотр логов
make gp-psql                    # Подключение к Greenplum
```

### Настройка подключения к Greenplum в Airflow

По умолчанию DAG использует переменные окружения, но вы можете создать Airflow Connection:

1. Airflow UI → **Admin → Connections → Add a new record**
2. Заполните поля:
   - **Conn Id:** `greenplum_conn`
   - **Conn Type:** `Postgres`
   - **Host:** `greenplum`
   - **Schema:** `gpadmin`
   - **Login:** `gpadmin`
   - **Password:** `gpadmin`
   - **Port:** `5432`

---

## 📋 Что входит в стенд

### Основные компоненты
- **Greenplum** — аналитическая база данных для хранения и анализа данных
- **Airflow** — оркестратор workflow и задач
- **Postgres** — база метаданных для Airflow
- **pandas** — библиотека для генерации и анализа данных в формате CSV

### Готовые DAG (workflow)
- **csv_to_greenplum** — базовый pipeline: pandas → CSV → Greenplum
- **greenplum_data_quality** — проверки качества данных (наличие таблицы, схема, дубликаты)

### Полезные команды
```bash
# Основные команды
make up                 # Запустить весь стенд
make down               # Остановить и удалить данные
make airflow-init       # Инициализировать Airflow
make ddl-gp             # Применить DDL к Greenplum
make gp-psql            # Подключиться к Greenplum через psql

# Проверка данных
make logs               # Следить за логами Airflow
```

---

## ⚙️ Настройка через переменные окружения

Все настройки находятся в файле `.env`. Основные параметры:

### Greenplum
- `GP_USER` — пользователь (по умолчанию: gpadmin)
- `GP_PASSWORD` — пароль (по умолчанию: gpadmin)
- `GP_DB` — база данных (по умолчанию: gpadmin)
- `GP_PORT` — порт (по умолчанию: 5432)

### CSV pipeline
- `CSV_DIR` — путь к каталогу с CSV внутри контейнеров Airflow (по умолчанию: `/opt/airflow/data`)
- `CSV_ROWS` — количество строк, генерируемых DAG (по умолчанию: 1000)

### Airflow
- `GP_CONN_ID` — ID подключения (по умолчанию: greenplum_conn)

---

## 🔍 Продвинутые темы

### Архитектура pipeline

**Поток данных в DAG `csv_to_greenplum`:**
1. `create_orders_table` — создаёт таблицу `public.orders` в Greenplum
2. `generate_csv` — генерирует датасет при помощи pandas и сохраняет CSV в `CSV_DIR`
3. `preview_csv` — выводит предпросмотр и статистику по данным
4. `load_csv_to_greenplum` — загружает CSV во временную таблицу и переносит новые строки в `public.orders`

> 💡 **Безопасность повторного запуска:** Pipeline защищен от дубликатов, поэтому его можно запускать многократно.

### Проверка качества данных

Запустите DAG `greenplum_data_quality` для автоматической проверки:
- Наличие таблицы в базе
- Соответствие схемы ожидаемой структуре
- Объем загруженных данных
- Отсутствие дубликатов записей

### Ограничения учебного стенда

- **Greenplum** запущен в single-node режиме (для обучения)
- В продакшене Greenplum обычно разворачивают кластером на нескольких серверах
- Используется Greenplum 6 (широко доступная версия), хотя Greenplum 7 предлагает больше возможностей

---

## 🆘 Типичные проблемы и решения

| Проблема | Решение |
|----------|---------|
| Airflow UI не открывается | Дождитесь сообщения `Listening at: http://0.0.0.0:8080` в логах (`make logs`) |
| Ошибка подключения к Greenplum | Убедитесь, что контейнер `greenplum` стал статусом `healthy` (проверьте `docker compose ps`) |
| Нет файла в `./data` после запуска DAG | Проверьте логи задачи `generate_csv`, убедитесь, что `CSV_DIR` смонтирован в docker-compose |
| Команда `make` не найдена | Используйте полные команды `docker compose` или установите make |
| Greenplum не стартует/падает при старте | Выполните `make down`, затем `make up && make airflow-init` (очищает тома и поднимает заново) |

---

## 📁 Структура проекта

```
├── docker-compose.yml     # Описание всех сервисов
├── .env.example           # Шаблон настроек
├── Makefile              # Удобные команды для работы
├── airflow/
│   └── dags/             # Файлы workflow (DAG)
│       ├── csv_to_greenplum.py
│       └── data_quality_greenplum.py
└── sql/
    └── ddl_gp.sql        # Создание таблицы в Greenplum
```

---

## 💡 Советы для дальнейшего обучения

1. **Поэкспериментируйте с DAG** — измените параметры генерации данных или размер батча
2. **Добавьте свои проверки** — расширьте DAG `data_quality_greenplum.py`
3. **Попробуйте другие источники** — замените генератор данных на чтение из файла или API
4. **Изучите Airflow deeper** — добавьте зависимости между задачами, настройте расписания

---

## ✅ Тестирование

- Локальные проверки: `make test` (pytest). Для форматирования — `make fmt`, для проверки — `make lint`.
- Пошаговый сценарий с Docker (включая негативные кейсы и reset) — см. `TESTING.md`.

Удачи в изучении Data Engineering! 🚀

