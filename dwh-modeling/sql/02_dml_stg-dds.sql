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
('batch_20250405_0800', '2025-04-05 08:00', NULL,  '101','a@ex.com','700','Москва'),
('batch_20250405_0800', '2025-04-05 08:00', NULL,  '102','c@ex.com','701','СПб'),
('batch_20250405_1200', '2025-04-05 12:00', NULL,  '101','b@ex.com','700','Москва'),
('batch_20250405_1800', '2025-04-05 18:00', NULL,  '101','b@ex.com','700','Санкт-Петербург');


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
-- ⚠️ В продакшене используем UPSERT или incremental load, не TRUNCATE+INSERT

TRUNCATE ods.customers, ods.orders, ods.order_items, ods.products;

INSERT INTO ods.orders (order_id, order_date, customer_id)
SELECT
    order_id::INT,
    TO_DATE(order_date, 'YYYY-MM-DD'),
    customer_id::INT
FROM stg.orders_raw
WHERE order_date IS NOT NULL AND customer_id ~ '^\d+$';

-- берём по BK самую позднюю запись (event_ts > _load_ts > _load_id)
WITH src AS (
  SELECT
      s.customer_id::INT                                     AS customer_id,
      NULLIF(trim(s.email), '')                              AS email,
      NULLIF(trim(s.phone), '')                              AS phone,
      NULLIF(trim(s.city),  '')                              AS city,
      NULLIF(s.event_ts, '')::timestamp                      AS event_ts,
      s._load_id,
      s._load_ts,
      COALESCE(NULLIF(s.event_ts, '')::timestamp, s._load_ts,
               to_timestamp(regexp_replace(s._load_id,'^batch_',''),'YYYYMMDD_HH24MI'))
          AS eff_ts
  FROM stg.customers_raw s
  WHERE s.customer_id ~ '^\d+$'
),
last_per_bk AS (
  SELECT DISTINCT ON (customer_id)
         customer_id, email, phone, city, event_ts, _load_id, _load_ts
  FROM src
  ORDER BY customer_id, eff_ts DESC, _load_ts DESC
)
INSERT INTO ods.customers (customer_id, email, phone, city, event_ts, _load_id, _load_ts)
SELECT customer_id, email, phone, city, event_ts, _load_id, _load_ts
FROM last_per_bk;

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
--    Здесь мы пересчитываем всю историю клиента из событий в STG.
--    В реальном DWH такую полную перезагрузку делают редко; для инкремента см. 03_demo_increment.sql и SCD.md.
TRUNCATE dds.dim_customer, dds.fact_sales;

BEGIN;
  WITH src AS (
    SELECT
      s.customer_id::INT                                         AS customer_bk,
      NULLIF(trim(s.email), '')                                   AS email,
      NULLIF(trim(s.phone), '')                                   AS phone,
      NULLIF(trim(s.city),  '')                                   AS city,
      COALESCE(NULLIF(s.event_ts,'')::timestamp, s._load_ts,
               to_timestamp(regexp_replace(s._load_id,'^batch_',''),'YYYYMMDD_HH24MI')) AS eff_ts,
      dds.customer_hash(s.email, s.phone, s.city)                 AS hashdiff
    FROM stg.customers_raw s
    WHERE s.customer_id ~ '^\d+$'
  ),
  ordered AS (
    SELECT *,
           lag(hashdiff) OVER (PARTITION BY customer_bk ORDER BY eff_ts) AS prev_hash,
           row_number()  OVER (PARTITION BY customer_bk ORDER BY eff_ts) AS rn
    FROM src
  ),
  changes AS (
    -- только первые состояния и фактические изменения атрибутов
    SELECT *
    FROM ordered
    WHERE prev_hash IS DISTINCT FROM hashdiff OR prev_hash IS NULL
  ),
  framed AS (
    SELECT
      customer_bk, email, phone, city, hashdiff,
      CASE WHEN rn = 1 THEN timestamp '1900-01-01' ELSE eff_ts END        AS valid_from,  -- первая версия: техническое "начало истории"
      lead(eff_ts) OVER (PARTITION BY customer_bk ORDER BY eff_ts)        AS next_ts
    FROM changes
  )
  INSERT INTO dds.dim_customer (
      customer_bk, email, phone, city, hashdiff,
      valid_from,                                           valid_to,                       is_current,
      created_at, updated_at
  )
  SELECT
      customer_bk, email, phone, city, hashdiff,
      valid_from,
      COALESCE(next_ts - interval '1 second', timestamp '9999-12-31') AS valid_to,
      (next_ts IS NULL)                                               AS is_current,
      now(), now()
  FROM framed
  ORDER BY customer_bk, valid_from;
COMMIT;

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
 AND o.order_date::timestamp BETWEEN dc.valid_from AND dc.valid_to;

-- 7. Проверка — вывод итогов (не часть ETL, но полезно для отладки)
-- В реальном пайплайне такие SELECT выносятся в отдельные скрипты или дашборды

 SELECT 'dim_customer count = ' || COUNT(*) FROM dds.dim_customer WHERE is_current ;
 SELECT 'fact_sales count = ' || COUNT(*) FROM dds.fact_sales;
