# DE Starter Kit — Greenplum + Kafka + Airflow

Добро пожаловать в учебный стенд для изучения основ Data Engineering! Этот проект поможет вам освоить ключевые инструменты современных data pipeline: **Airflow** для оркестрации, **Kafka** для потоковой передачи данных и **Greenplum** как аналитическую базу данных.

## 🎯 Что вы узнаете

- Как настроить локальный стек данных с помощью Docker
- Как Airflow управляет workflow и координирует задачи
- Как данные перемещаются из Kafka в аналитическую базу
- Как проверять качество данных в автоматизированных pipeline
- Основы проектирования ETL/ELT процессов

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
2. Найдите DAG с названием **kafka_to_greenplum**
3. Нажмите на переключатель слева от названия DAG, чтобы включить его
4. Нажмите кнопку **Trigger** (значок воспроизведения ▶️)

🎉 **Поздравляем!** Вы только что запустили свой первый data pipeline:
- Система сгенерировала 1000 тестовых заказов
- Данные отправились в Kafka (систему потоковой передачи сообщений)
- Airflow прочитал данные из Kafka и загрузил их в Greenplum

### Шаг 4: Проверка результатов

**Через веб-интерфейс:**
- Kafka UI: **http://localhost:8082** — посмотрите топик `orders` и сообщения
- Airflow UI: **http://localhost:8080** — отслеживайте выполнение задач

**Через командную строку:**
```bash
# Подключитесь к Greenplum и проверьте данные
docker compose exec greenplum bash -c "su - gpadmin -c 'psql -p 5432 -d gpadmin'"

# Внутри psql выполните:
\dt                    # Показать таблицы
SELECT count(*) FROM public.orders;  # Посчитать записи
```

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
- **Kafka** — система потоковой передачи данных (без Zookeeper)
- **Airflow** — оркестратор workflow и задач
- **Postgres** — база метаданных для Airflow

### Готовые DAG (workflow)
- **kafka_to_greenplum** — базовый pipeline: генерация → Kafka → Greenplum
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

### Kafka
- `KAFKA_TOPIC` — имя топика (по умолчанию: orders)
- `KAFKA_BATCH_SIZE` — размер пакета при загрузке (по умолчанию: 500)

### Airflow
- `GP_CONN_ID` — ID подключения (по умолчанию: greenplum_conn)

---

## 🔍 Продвинутые темы

### Архитектура pipeline

**Поток данных в DAG `kafka_to_greenplum`:**
1. `create_table` — создает таблицу `public.orders` в Greenplum
2. `produce_messages` — генерирует и отправляет сообщения в Kafka
3. `consume_and_load` — читает из Kafka и загружает в Greenplum батчами

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
| Нет топика `orders` в Kafka | Создайте топик через Kafka UI или дождитесь авто-создания при первом запуске DAG |
| Команда `make` не найдена | Используйте полные команды `docker compose` или установите make |

---

## 📁 Структура проекта

```
├── docker-compose.yml     # Описание всех сервисов
├── .env.example           # Шаблон настроек
├── Makefile              # Удобные команды для работы
├── airflow/
│   └── dags/             # Файлы workflow (DAG)
│       ├── kafka_to_greenplum.py
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

Удачи в изучении Data Engineering! 🚀
