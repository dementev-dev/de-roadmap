# Postgres + demoDB "bookings" в Docker — README для менти

Этот стенд поднимает локальный PostgreSQL в Docker и загружает учебную БД **Postgres Pro demo “Airlines/Bookings”**. После запуска можно работать через `psql` (внутри контейнера) и через DBeaver (с хоста).

---

## Что нужно заранее
- **Docker Desktop** (Windows/macOS) или **Docker Engine** (Linux) + **docker compose**.
- Утилита `unzip` (Linux: `sudo apt install unzip` / `sudo dnf install unzip`).
- Свободный порт **5432** (или задайте другой через `.env`).
- Windows: желательно запускать команды в **WSL2** либо в **Git Bash** (так проще с shell‑скриптами и LF‑окончаниями).

Проверка окружения:
```bash
docker --version
docker compose version
```

---

## Состав проекта (что у вас должно быть в папке)
```
postgres-bookings/
├─ docker-compose.yml
├─ .env                 # опционально: логин/пароль/порт
├─ initdb/
│   ├─ 00_init.sql      # создаёт БД demo (страхует первый запуск)
│   └─ 01_bookings.sql  # скрипт с учебными данными
└─ psql_sh              # помощник: открыть psql внутри контейнера
```

> Если нет файлов `initdb/00_init.sql` и `initdb/01_bookings.sql`, запустите скрипт ниже (раздел «Быстрый старт», шаг 1).

---

## Быстрый старт (Linux/macOS/WSL2)
1) Подготовьте init‑скрипты (скачивание демо‑БД):
```bash
bash download_db.sh
chmod +x psql_sh
```
2) Поднимите кластер:
```bash
docker compose up -d
```
3) Проверьте, что сервис готов (статус `healthy`) и подключайтесь:
```bash
docker compose ps
./psql_sh
```
Внутри `psql` можно проверить данные:
```sql
\dt;
SELECT COUNT(*) FROM bookings.flights;
```

> **DBeaver:** Host `127.0.0.1`, Port `5432` (или ваш из `.env`), Database `demo`, User `postgres`, Password `postgres`, SSL — Off.

---

## Как поменять порт/логин/пароль
Создайте файл `.env` в корне проекта:
```ini
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
PG_PORT=5432
```
Перезапустите контейнеры:
```bash
docker compose down && docker compose up -d
```

---

## Частые команды
```bash
# запустить в фоне / остановить
docker compose up -d
docker compose down

# статус и логи
docker compose ps
docker compose logs -f --tail=200

# открыть psql
./psql_sh
```

---

## Сброс и повторная заливка
> Автозагрузка из `initdb/` выполняется **только** при первом старте с пустым томом данных.

- Полный сброс и переинициализация:
```bash
docker compose down -v && docker compose up -d
```
- Перезалить данные без удаления тома:
```bash
docker compose exec -T db psql -U postgres -d postgres \
  -f /docker-entrypoint-initdb.d/01_bookings.sql
```

---

## Частые проблемы и решения
- **Порт 5432 занят.** Поменяйте `PG_PORT` в `.env`, затем `docker compose down && docker compose up -d`.
- **`./psql_sh: Permission denied`.** Дайте права: `chmod +x psql_sh`.
- **`psql: could not connect to server` / статус не `healthy`.** Смотрите логи: `docker compose logs -f --tail=200`.
- **Windows и CRLF.** Если редактировали файлы Блокнотом, убедитесь в LF‑окончаниях (используйте Git Bash/WSL2).
- **`unzip: command not found` (Linux).** Установите `unzip` командой дистрибутива.

---

## Зачем нужен `00_init.sql`?
Учебный скрипт `01_bookings.sql` начинается с `DROP DATABASE demo;` (без `IF EXISTS`). На самом первом запуске БД `demo` ещё нет, поэтому `DROP` вызвал бы ошибку. Файл `00_init.sql` предварительно создаёт БД `demo`, чтобы импорт прошёл без сбоев.

---

## Что внутри демо‑БД
Схема `bookings`: таблицы `airports`, `aircrafts`, `flights`, `tickets`, `ticket_flights`, `boarding_passes` и др. Идеально для практики `JOIN`, оконных функций, индексов и анализа планов (`EXPLAIN ANALYZE`).

> **Безопасность:** значения по умолчанию (`postgres/postgres`) — только для учебных целей на локальной машине. Для реальных проектов используйте сильные пароли и SSL.

