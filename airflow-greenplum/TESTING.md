# План тестирования (для студентов)

Этот документ — пошаговый чек‑лист, как проверить, что всё работает: от «быстрых локальных проверок» до запуска стенда в Docker и просмотра данных в Greenplum. Подходит начинающим: просто выполняйте шаги по порядку.

Если что‑то пошло не так, смотрите раздел «Быстрый reset» ниже.

## 1. Быстрая проверка окружения
- `uv sync` — подтягиваем Python и зависимости из `pyproject.toml`/`uv.lock`.
- Проверяем версию uv: `uv --version` (ожидаем ≥ 0.9).
- Убедитесь, что `docker compose version` доступна и Docker запущен.

## 2. Локальные автоматические проверки (без Docker)
- `make test` — короткие unit-тесты (`tests/test_greenplum_helpers.py`, `tests/test_dags_smoke.py`).
  - Smoke-тесты DAG автоматически `skip`, если Airflow не установлен в venv, поэтому прогонится за миллисекунды.
- `make lint` — black/isort в режиме проверки. Сейчас упадёт из‑за форматирования DAG-файлов.
- `make fmt` — автоисправление форматирования; после этого `make lint` должен пройти.
- (опционально) `uv run pytest -q -k dags_smoke` — только DAG smoke.

## 3. Подготовка Docker-стенда
- `cp .env.example .env` (если файла ещё нет) и проверьте переменные:
  - `GP_PORT` не конфликтует с локальным PostgreSQL.
  - `GP_USE_AIRFLOW_CONN=true` при желании использовать Airflow Connection; `false` — fallback на ENV.
- `make up` — поднимаем все сервисы. Важно дождаться статуса `healthy` у `pgmeta` и `greenplum` (`docker compose ps`).
- `make airflow-init` — миграции мета-БД и создание пользователя Airflow; занимает ~1–2 минуты.
- `make logs` — следим, пока webserver и scheduler не перейдут в рабочее состояние (`Listening at: http://0.0.0.0:8080`).

## 4. Smoke тесты DAG в Airflow UI
1. Открыть http://localhost:8080 (admin/admin).
2. DAG `csv_to_greenplum`:
   - Включить переключатель.
   - Нажать «Trigger DAG».
   - Контроль: все таски Success, в `data/` появился CSV, в логах `load_csv_to_greenplum` видно `INSERT`.
   - В Greenplum (см. п.5) убедиться в наличии строк `(SELECT COUNT(*) ...)`.
3. DAG `greenplum_data_quality`:
   - Запустить вручную после первого DAG.
   - Проверить, что все 5 задач Success и логи содержат `Проверка пройдена`.

## 5. Проверка данных в Greenplum
- `make gp-psql` — запустить psql в контейнере от имени `gpadmin`.
- Команды внутри psql:
  - `\dt public.*` — таблицы схему public.
  - `SELECT COUNT(*) FROM public.orders;` — оценка объёма.
  - `SELECT * FROM public.orders LIMIT 5;` — визуальная проверка.
  - `SELECT order_id FROM public.orders GROUP BY 1 HAVING COUNT(*) > 1;` — поиск дублей.
- Завершить `\q`.

## 6. Негативные сценарии и fallback
- **Пустая таблица**: запустить `greenplum_data_quality` до `csv_to_greenplum`. Ожидается ошибка на таске `check_orders_has_rows`.
- **Проблемы с подключением**: временно изменить `GP_HOST` или `GP_PORT` на несуществующий, перезапустить `make up`, убедиться, что DAG падает с понятной ошибкой (`psycopg2.OperationalError`).
- **Fallback без Airflow Connection**: установить `GP_USE_AIRFLOW_CONN=false`, перезапустить стек (`make down && make up && make airflow-init`), удостовериться, что загрузка и DQ работают через ENV.
- **Дубликаты**: дважды вызвать `csv_to_greenplum` — ожидаем, что количество строк в `public.orders` не увеличится на размер CSV, а DAG `greenplum_data_quality` не найдёт дублей.

## 7. Быстрый reset (если «что-то сломалось»)
- Перезапустить стенд с очисткой данных:
  - `make down` — остановит контейнеры и удалит тома.
  - `make up && make airflow-init` — заново поднимет всё и проинициализирует Airflow.
- Иногда Greenplum не стартует после «грязных» остановок (из‑за старых внутренних файлов). Лечение: всегда делайте `make down` перед повторным `make up`.

## 8. Снятие метрик и мониторинг
- Контейнеры: `docker compose ps`, `docker stats` (по желанию).
- Логи задач: в Airflow UI → конкретный таск → Log.
- Хостовые CSV: каталог `data/` (можно открыть любой файл и убедиться в структуре).

## 9. Завершение работы
- `make down` — выключает сервисы и удаляет тома (перезапишет данные в Greenplum!).
- При необходимости сохранить данные: скопировать CSV из `data/` и дампы из контейнера до `make down`.

## Текущий статус (пример успешного прогона)
- `uv run pytest -q` — 11 passed, 2 smoke-теста DAG пропущены (Airflow не установлен в venv).
- `make lint` — падает, потому что `airflow/dags/*.py` не отформатированы black/isort. После `make fmt` проблема уйдёт.
- Docker-стенд не запускался в рамках этой сессии; ожидается, что инструкции выше обеспечат полноценную проверку.
