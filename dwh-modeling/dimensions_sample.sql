-- ===============================================
-- 1. Создание схем
-- ===============================================
DROP SCHEMA IF EXISTS stg CASCADE;
DROP SCHEMA IF EXISTS ods CASCADE;
DROP SCHEMA IF EXISTS dds CASCADE;
CREATE SCHEMA stg;
CREATE SCHEMA ods;
CREATE SCHEMA dds;

-- ===============================================
-- 2. STG: таблицы «как пришло»
-- ===============================================

-- Сырые данные: строки, как из CSV/API
CREATE TABLE stg.customers_raw (
    customer_id TEXT,        -- может быть '101' или 'CUST-101'
    email       TEXT,
    phone       TEXT,
    city        TEXT,
    _load_ts    TIMESTAMP DEFAULT NOW()
);

CREATE TABLE stg.orders_raw (
    order_id    TEXT,
    order_date  TEXT,       -- формат: '2024-01-10'
    customer_id TEXT
);

CREATE TABLE stg.order_items_raw (
    order_item_id   TEXT,
    order_id        TEXT,
    product_id      TEXT,
    qty             TEXT,   -- может быть '2', 'NULL'
    price_at_sale   TEXT    -- может быть '100.00'
);

CREATE TABLE stg.products_raw (
    product_id TEXT,
    name       TEXT
);

-- Загрузка тестовых данных (вместо COPY FROM CSV)
INSERT INTO stg.customers_raw (customer_id, email, phone, city) VALUES
('101', 'a@ex.com', '700', 'Москва'),
('101', 'b@ex.com', '700', 'Москва'),  -- изменение email
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

-- ===============================================
-- 3. ODS: очистка и типизация
-- ===============================================

-- Очищенные клиенты
CREATE TABLE ods.customers AS
SELECT
    customer_id::INT AS customer_id,            -- приведение к INT
    NULLIF(TRIM(email), '') AS email,           -- пустые → NULL
    NULLIF(TRIM(phone), '') AS phone,
    NULLIF(TRIM(city), '') AS city
FROM stg.customers_raw
WHERE customer_id ~ '^\d+$';  -- валидация: только цифры

-- Очищенные заказы
CREATE TABLE ods.orders AS
SELECT
    order_id::INT,
    TO_DATE(order_date, 'YYYY-MM-DD') AS order_date,
    customer_id::INT
FROM stg.orders_raw
WHERE order_date IS NOT NULL AND customer_id ~ '^\d+$';

-- Очищенные позиции заказа
CREATE TABLE ods.order_items AS
SELECT
    order_item_id::INT,
    order_id::INT,
    product_id::INT,
    NULLIF(qty, '')::INT AS qty,
    NULLIF(price_at_sale, '')::NUMERIC(10,2) AS price_at_sale
FROM stg.order_items_raw
WHERE qty ~ '^\d+$' AND price_at_sale ~ '^\d+(\.\d+)?$';

-- Очищенные товары
CREATE TABLE ods.products AS
SELECT
    product_id::INT,
    TRIM(name) AS name
FROM stg.products_raw
WHERE product_id ~ '^\d+$';

-- Добавим первичные ключи (для ускорения JOIN и проверки)
ALTER TABLE ods.customers  ADD PRIMARY KEY (customer_id);
ALTER TABLE ods.orders     ADD PRIMARY KEY (order_id);
ALTER TABLE ods.order_items ADD PRIMARY KEY (order_item_id);
ALTER TABLE ods.products   ADD PRIMARY KEY (product_id);

-- ===============================================
-- 4. DDS: интеграция + SCD Type 2
-- ===============================================

-- 4.1 dim_date — справочник дат (на 5 лет: 2023–2027)
CREATE TABLE dds.dim_date AS
WITH RECURSIVE dates AS (
    SELECT DATE '2023-01-01' AS d
    UNION ALL
    SELECT d + INTERVAL '1 day'
    FROM dates
    WHERE d + INTERVAL '1 day' <= DATE '2027-12-31'
)
SELECT
    CAST(TO_CHAR(d, 'YYYYMMDD') AS INT) AS date_key,
    d AS date_actual,
    EXTRACT(YEAR FROM d) AS year,
    EXTRACT(QUARTER FROM d) AS quarter,
    EXTRACT(MONTH FROM d) AS month,
    EXTRACT(DAY FROM d) AS day,
    TO_CHAR(d, 'Day') AS weekday_name,
    EXTRACT(DOW FROM d) AS weekday_num,  -- 0 = воскресенье
    d BETWEEN 
        DATE_TRUNC('month', d) 
        AND DATE_TRUNC('month', d) + INTERVAL '1 month' - INTERVAL '1 day'
        AND EXTRACT(DAY FROM d) <= 7 
        AS is_first_week
FROM dates;

ALTER TABLE dds.dim_date ADD PRIMARY KEY (date_key);

-- 4.2 dim_product — измерение «Товар» (без истории — атрибуты стабильны)
CREATE TABLE dds.dim_product (
    product_sk   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_bk   INT NOT NULL,
    product_name VARCHAR(100) NOT NULL
);

INSERT INTO dds.dim_product (product_bk, product_name)
SELECT product_id, name
FROM ods.products;

-- 4.3 dim_customer — SCD Type 2 (с историей)
CREATE TABLE dds.dim_customer (
    customer_sk   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_bk   INT NOT NULL,
    email         VARCHAR(100),
    phone         VARCHAR(20),
    city          VARCHAR(50),
    valid_from    DATE NOT NULL,
    valid_to      DATE NOT NULL DEFAULT '9999-12-31',
    is_current    BOOLEAN NOT NULL DEFAULT TRUE
);

-- Загрузка первой версии (SCD Type 2 — простой алгоритм)
-- Группируем по customer_bk и сортируем по времени (по _load_ts из STG)
-- Для учебного примера имитируем хронологию через порядок строк
WITH ranked AS (
    SELECT
        customer_id AS customer_bk,
        email,
        phone,
        city,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY _load_ts, email  -- хронология изменений
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
        -- начальная дата — день первого появления в источнике
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
        CASE WHEN
            LEAD(eff_from) OVER (PARTITION BY customer_bk ORDER BY eff_from) IS NULL
        THEN TRUE ELSE FALSE END AS is_current
    FROM changes
)
INSERT INTO dds.dim_customer (customer_bk, email, phone, city, valid_from, valid_to, is_current)
SELECT customer_bk, email, phone, city, valid_from, valid_to, is_current
FROM final;

-- 4.4 fact_sales — факт продаж
CREATE TABLE dds.fact_sales (
    sale_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_sk  BIGINT NOT NULL,  -- ссылка на DDS-измерение
    product_sk   BIGINT NOT NULL,
    date_key     INT NOT NULL,     -- YYYYMMDD
    quantity     INT NOT NULL CHECK (quantity > 0),
    amount       NUMERIC(18,2) NOT NULL CHECK (amount >= 0)
);

-- Заполнение fact_sales с учётом истории клиента (SCD!)
INSERT INTO dds.fact_sales (customer_sk, product_sk, date_key, quantity, amount)
SELECT
    dc.customer_sk,
    dp.product_sk,
    CAST(TO_CHAR(o.order_date, 'YYYYMMDD') AS INT) AS date_key,
    oi.qty,
    oi.price_at_sale * oi.qty AS amount
FROM ods.orders o
JOIN ods.order_items oi ON o.order_id = oi.order_id
JOIN ods.products p ON oi.product_id = p.product_id
JOIN dds.dim_product dp ON p.product_id = dp.product_bk
JOIN dds.dim_customer dc 
    ON o.customer_id = dc.customer_bk
    AND o.order_date BETWEEN dc.valid_from AND dc.valid_to;  -- ← ключевая строка SCD!

-- Добавим внешние ключи (опционально, для целостности)
ALTER TABLE dds.fact_sales 
    ADD FOREIGN KEY (customer_sk) REFERENCES dds.dim_customer(customer_sk),
    ADD FOREIGN KEY (product_sk) REFERENCES dds.dim_product(product_sk),
    ADD FOREIGN KEY (date_key) REFERENCES dds.dim_date(date_key);

-- ===============================================
-- 5. Проверка: посчитаем выручку по клиентам
-- ===============================================
SELECT
    dc.customer_bk,
    dc.email,
    dc.city,
    SUM(f.amount) AS total_revenue
FROM dds.fact_sales f
JOIN dds.dim_customer dc 
    ON f.customer_sk = dc.customer_sk
    AND dc.is_current  -- только актуальная версия
GROUP BY dc.customer_bk, dc.email, dc.city
ORDER BY total_revenue DESC;
