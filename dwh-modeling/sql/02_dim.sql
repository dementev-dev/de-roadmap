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

INSERT INTO stg.customers_raw (customer_id, email, phone, city) VALUES
('101', 'a@ex.com', '700', 'Москва'),
('101', 'b@ex.com', '700', 'Москва'),
('102', 'c@ex.com', '701', 'СПб');

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

INSERT INTO ods.customers (customer_id, email, phone, city)
SELECT
    customer_id::INT,
    NULLIF(TRIM(email), ''),
    NULLIF(TRIM(phone), ''),
    NULLIF(TRIM(city), '')
FROM stg.customers_raw
WHERE customer_id ~ '^\d+$';

INSERT INTO ods.orders (order_id, order_date, customer_id)
SELECT
    order_id::INT,
    TO_DATE(order_date, 'YYYY-MM-DD'),
    customer_id::INT
FROM stg.orders_raw
WHERE order_date IS NOT NULL AND customer_id ~ '^\d+$';

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
    SELECT d + INTERVAL '1 day'
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
    TO_CHAR(d, 'Day'),
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

-- 5. DDS: dim_customer — SCD Type 2 (упрощённая версия для обучения)
-- В продакшене — используем алгоритм «детектирования изменений + UPSERT»
-- Здесь: перестраиваем всю историю на основе STG (для детерминированности)

DELETE FROM dds.dim_customer;

WITH ranked AS (
    SELECT
        customer_id::INT AS customer_bk,
        email,
        phone,
        city,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY _load_ts, email
        ) AS rn
    FROM stg.customers_raw
    WHERE customer_id ~ '^\d+$'
),
changes AS (
    SELECT
        customer_bk,
        email,
        phone,
        city,
        -- Имитируем хронологию: +1 день на каждое изменение
        '2023-01-01'::DATE + (rn - 1) * INTERVAL '1 day' AS eff_from
    FROM ranked
),
final AS (
    SELECT
        customer_bk,
        email,
        phone,
        city,
        eff_from::DATE AS valid_from,
        COALESCE(
            LEAD(eff_from) OVER (PARTITION BY customer_bk ORDER BY eff_from) - INTERVAL '1 day',
            '9999-12-31'::DATE
        ) AS valid_to,
        CASE WHEN LEAD(eff_from) OVER (PARTITION BY customer_b_k ORDER BY eff_from) IS NULL
             THEN TRUE ELSE FALSE END AS is_current
    FROM changes
)
INSERT INTO dds.dim_customer (customer_bk, email, phone, city, valid_from, valid_to, is_current)
SELECT customer_bk, email, phone, city, valid_from, valid_to, is_current
FROM final;

-- 6. DDS: fact_sales — загрузка фактов с учётом SCD
-- В продакшене — фильтруем по диапазону дат (инкрементально)

DELETE FROM dds.fact_sales;

INSERT INTO dds.fact_sales (customer_sk, product_sk, date_key, quantity, amount)
SELECT
    dc.customer_sk,
    dp.product_sk,
    CAST(TO_CHAR(o.order_date, 'YYYYMMDD') AS INT),
    oi.qty,
    oi.price_at_sale * oi.qty
FROM ods.orders o
JOIN ods.order_items oi ON o.order_id = oi.order_id
JOIN ods.products p ON oi.product_id = p.product_id
JOIN dds.dim_product dp ON p.product_id = dp.product_bk
JOIN dds.dim_customer dc 
    ON o.customer_id = dc.customer_bk
    AND o.order_date BETWEEN dc.valid_from AND dc.valid_to;

-- 7. Проверка — вывод итогов (не часть ETL, но полезно для отладки)
-- В реальном пайплайне такие SELECT выносятся в отдельные скрипты или дашборды

-- SELECT 'dim_customer count = ' || COUNT(*) FROM dds.dim_customer;
-- SELECT 'fact_sales count = ' || COUNT(*) FROM dds.fact_sales;
