-- ===============================================
-- DML-скрипт: загрузка и трансформация данных
-- Запускается ПОВТОРНО при каждой загрузке (идемпотентно!)
-- ===============================================

-- 1. STG: имитация загрузки из источников (в реальности — COPY или INSERT из Kafka/NiFi)
-- ⚠️ В продакшене STG часто очищается перед загрузкой (TRUNCATE), либо используется партицирование по дате

DELETE FROM stg.customers_raw;
DELETE FROM stg.orders_raw;
DELETE FROM stg.order_items_raw;
DELETE FROM stg.products_raw;

-- STG (пример вставки с метками времени)
INSERT INTO stg.customers_raw (_load_id, _load_ts, event_ts, customer_id, email, phone, city) VALUES
('batch_20240101_0800', '2024-01-01 08:00', '2024-01-01',  '101','a@ex.com','700','Москва'),
('batch_20240101_0800', '2024-01-01 08:00', '2024-01-01',  '102','c@ex.com','701','СПб'),
('batch_20240516_0800', '2024-05-16 08:00', '2024-05-16',  '101','b@ex.com','700','Москва'),
('batch_20241001_0800', '2024-10-01 08:00', '2024-10-01',  '101','b@ex.com','700','Санкт-Петербург');


INSERT INTO stg.orders_raw (order_id, order_date, customer_id) VALUES
('5001', '2024-01-10', '101'),
('5002', '2024-02-05', '102');

INSERT INTO stg.order_items_raw (order_item_id, order_id, product_id, qty, price_at_sale) VALUES
('1', '5001', '9001', '2', '100.00'),
('2', '5001', '9002', '1', '50.00'),
('3', '5002', '9001', '1', '100.00');

INSERT INTO stg.products_raw (product_id, name) VALUES
('9001', 'Phone'),
('9002', 'Case');

-- 2. ODS: очистка и типизация
-- ⚠️ В продакшене используем UPSERT (INSERT ... ON CONFLICT DO UPDATE) или incremental load, не TRUNCATE+INSERT

TRUNCATE ods.customers, ods.orders, ods.order_items, ods.products;

INSERT INTO ods.orders (order_id, order_date, customer_id)
SELECT
    order_id::INT,
    TO_DATE(order_date, 'YYYY-MM-DD'),
    customer_id::INT
FROM stg.orders_raw
WHERE order_date IS NOT NULL AND customer_id ~ '^\d+$';

-- берём по BK самую позднюю запись (по дате события, иначе по дате загрузки)
WITH src AS (
  SELECT
      s.customer_id::INT                                     AS customer_id,
      NULLIF(trim(s.email), '')                              AS email,
      NULLIF(trim(s.phone), '')                              AS phone,
      NULLIF(trim(s.city),  '')                              AS city,
      NULLIF(s.event_ts, '')::timestamp                      AS event_ts,
      s._load_id,
      s._load_ts,
      COALESCE(NULLIF(s.event_ts, '')::date, s._load_ts::date) AS eff_date
  FROM stg.customers_raw s
  WHERE s.customer_id ~ '^\d+$'
),
ranked AS (
  SELECT
         customer_id, email, phone, city, event_ts, _load_id, _load_ts,
         row_number() OVER (PARTITION BY customer_id ORDER BY eff_date DESC, _load_ts DESC) AS rn
  FROM src
)
INSERT INTO ods.customers (customer_id, email, phone, city, event_ts, _load_id, _load_ts)
SELECT customer_id, email, phone, city, event_ts, _load_id, _load_ts
FROM ranked
WHERE rn = 1;

INSERT INTO ods.order_items (order_item_id, order_id, product_id, qty, price_at_sale)
SELECT
    order_item_id::INT,
    order_id::INT,
    product_id::INT,
    NULLIF(qty, '')::INT,
    NULLIF(price_at_sale, '')::NUMERIC(10,2)
FROM stg.order_items_raw
WHERE qty ~ '^\d+$' AND price_at_sale ~ '^\d+(\.\d+)?$';

INSERT INTO ods.products (product_id, name)
SELECT
    product_id::INT,
    TRIM(name)
FROM stg.products_raw
WHERE product_id ~ '^\d+$';

-- 3. DDS: dim_date — генерация календаря (идемпотентно: можно пересоздавать)
-- В реальности — делается ОДИН РАЗ, либо дополняется по мере необходимости

DELETE FROM dds.dim_date;

WITH RECURSIVE dates AS (
    SELECT DATE '2023-01-01' AS d
    UNION ALL
    SELECT (d + INTERVAL '1 day')::DATE  -- ← приведение к DATE
    FROM dates
    WHERE d + INTERVAL '1 day' <= DATE '2027-12-31'
)
INSERT INTO dds.dim_date (
    date_key, date_actual, year, quarter, month, day,
    weekday_name, weekday_num, is_first_week
)
SELECT
    CAST(TO_CHAR(d, 'YYYYMMDD') AS INT),
    d,
    EXTRACT(YEAR FROM d)::SMALLINT,
    EXTRACT(QUARTER FROM d)::SMALLINT,
    EXTRACT(MONTH FROM d)::SMALLINT,
    EXTRACT(DAY FROM d)::SMALLINT,
    TRIM(TO_CHAR(d, 'Day')),  -- ← TRIM — убрать trailing space
    EXTRACT(DOW FROM d)::SMALLINT,
    d BETWEEN DATE_TRUNC('month', d) 
          AND DATE_TRUNC('month', d) + INTERVAL '1 month' - INTERVAL '1 day'
      AND EXTRACT(DAY FROM d) <= 7
FROM dates;

-- 4. DDS: dim_product — полная перезагрузка (если товары редко меняются)
-- В реальности — инкрементальная загрузка по BK

DELETE FROM dds.dim_product;

INSERT INTO dds.dim_product (product_bk, product_name)
SELECT product_id, name
FROM ods.products;

-- 5. DDS: dim_customer — первичная загрузка SCD2 (full backfill из STG)
--    В ЭТОМ ДЕМО: dim_customer строится напрямую из stg.customers_raw, который играет роль
--    устойчивого event-лога (все события по клиенту в одном месте).
--    Это удобно для учебной первичной загрузки (full backfill), когда мы один раз
--    восстанавливаем всю историю клиента.
--    В РЕАЛЬНОМ DWH: так делают редко. Исторические измерения обычно строят
--    поверх очищенных и нормализованных слоёв (ODS / PSA / Data Vault).
--    Для примера инкрементальной заливки SCD2 по снимку из ODS см. 03_demo_increment.sql и SCD.md.
--
-- Идея SCD2 простыми словами:
--   - одна строка = один период, когда атрибуты клиента (email/phone/city) были одинаковыми;
--   - valid_from = дата, когда "стало так";
--   - valid_to = дата следующего изменения (NULL = текущая версия).
--
-- Откуда берём дату изменения:
--   - если в событии есть event_ts — считаем, что изменение произошло тогда;
--   - если event_ts пустой — берём дату загрузки (_load_ts), чтобы не терять историю.
--
-- Важно для демо: считаем, что у клиента не бывает двух разных изменений в один и тот же день.
TRUNCATE dds.dim_customer, dds.fact_sales;

WITH src AS (  -- 1) Приводим типы, готовим дату изменения (eff_date) и считаем hashdiff атрибутов
  SELECT
    s.customer_id::INT                                         AS customer_bk,
    NULLIF(trim(s.email), '')                                   AS email,
    NULLIF(trim(s.phone), '')                                   AS phone,
    NULLIF(trim(s.city),  '')                                   AS city,
    COALESCE(NULLIF(s.event_ts, '')::date, s._load_ts::date)     AS eff_date,
    dds.customer_hash(s.email, s.phone, s.city)                 AS hashdiff
  FROM stg.customers_raw s
  WHERE s.customer_id ~ '^\d+$'
),
ordered AS (  -- 2) Сортируем по датам и смотрим "какой hashdiff был до этого" (LAG)
  SELECT *,
          lag(hashdiff) OVER (PARTITION BY customer_bk ORDER BY eff_date) AS prev_hash
  FROM src
),
changes AS (  -- 3) Оставляем только первое состояние и реальные изменения (где hashdiff поменялся)
  SELECT *
  FROM ordered
  WHERE prev_hash IS DISTINCT FROM hashdiff OR prev_hash IS NULL
),
framed AS (  -- 4) Превращаем изменения в периоды: valid_to = дата следующего изменения (LEAD)
  SELECT
    customer_bk, email, phone, city, hashdiff,
    eff_date                                                         AS valid_from,
    lead(eff_date) OVER (PARTITION BY customer_bk ORDER BY eff_date)  AS valid_to
  FROM changes
)
INSERT INTO dds.dim_customer (
    customer_bk, email, phone, city, hashdiff,
    valid_from,                                           valid_to,
    created_at, updated_at
)
SELECT
    customer_bk, email, phone, city, hashdiff,
    valid_from,
    valid_to,
    now(), now()
FROM framed
ORDER BY customer_bk, valid_from;

-- 6. DDS: fact_sales — загрузка фактов с учётом SCD
-- В продакшене — фильтруем по диапазону дат (инкрементально)

--TRUNCATE dds.fact_sales;

INSERT INTO dds.fact_sales (customer_sk, product_sk, date_key, quantity, amount)
SELECT
    dc.customer_sk,
    dp.product_sk,
    CAST(TO_CHAR(o.order_date, 'YYYYMMDD') AS INT),
    oi.qty,
    oi.price_at_sale * oi.qty
FROM ods.orders o
JOIN ods.order_items oi ON o.order_id = oi.order_id
JOIN ods.products p     ON oi.product_id = p.product_id
JOIN dds.dim_product dp ON p.product_id = dp.product_bk
JOIN dds.dim_customer dc
  ON o.customer_id = dc.customer_bk
 AND o.order_date >= dc.valid_from
 AND (dc.valid_to IS NULL OR o.order_date < dc.valid_to);

-- 7. Проверка — вывод итогов (не часть ETL, но полезно для отладки)
-- В реальном пайплайне такие SELECT выносятся в отдельные скрипты или дашборды

 SELECT 'dim_customer current = ' || COUNT(*) FROM dds.dim_customer WHERE valid_to IS NULL;
 SELECT 'fact_sales count = ' || COUNT(*) FROM dds.fact_sales;
