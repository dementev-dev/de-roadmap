-- ===============================================
-- DML-шаблон для домашки
-- Тема: статусы клиента (STG → ODS → DDS SCD2)
-- Цель: по customer_status_events.csv построить историю статусов
-- ===============================================

-- Подсказка:
-- 1) Загрузите CSV в stg.customer_status_raw (через COPY или \copy в psql).
--    См. пример структуры файла в dwh-modeling/data/customer_status_events.csv
-- 2) Переложите данные в ods.customer_status с приведением типов.
--    customer_id → INT, status → VARCHAR(20), event_ts / load_ts → TIMESTAMP.
-- 3) Постройте из ods.customer_status измерение dds.dim_customer_status в стиле SCD2:
--    - одна строка на период действия статуса (valid_from / valid_to);
--    - is_current = TRUE только у актуальной строки для клиента;
--    - hashdiff можно считать, например, от одного поля status.
-- 4) При желании добавьте инкрементальную логику (как в 03_demo_increment.sql).
-- 5) Опционально: соберите витрину dm.mart_customer_status_daily
--    с количеством клиентов по статусам на каждую дату.

-- Ниже — ЗАГОТОВКИ блоков, которые можно дописать.
-- Они намеренно оставлены пустыми, чтобы вы написали SQL сами.

-- 1. ODS: очистка и типизация
-- TRUNCATE ods.customer_status;
-- INSERT INTO ods.customer_status (...)
-- SELECT ...
-- FROM stg.customer_status_raw;

-- 2. DDS: начальная загрузка SCD2
-- Примерный план:
--   - рассчитать hashdiff по (status);
--   - по каждому клиенту отсортировать события по времени;
--   - построить для каждой строки valid_from и valid_to (LEAD() OVER ...);
--   - вставить в dds.dim_customer_status.

-- 3. DDS: инкрементальная загрузка (по желанию)
-- Можно ориентироваться на примеры в 03_demo_increment.sql.

-- 4. DM: витрина статусов клиентов по датам (по желанию)
-- Пример целевой структуры:
-- CREATE TABLE dm.mart_customer_status_daily (
--     date_actual    DATE        NOT NULL,
--     status         VARCHAR(20) NOT NULL,
--     customers_cnt  INT         NOT NULL
-- );
-- Идея: на каждую дату взять актуальный статус клиента
-- через JOIN dds.dim_customer_status + dds.dim_date.

