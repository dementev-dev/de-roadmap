-- ===============================================
-- DDL-скрипт: определение структуры хранилища
-- Запускается ОДИН РАЗ при инициализации БД
-- или при изменении схемы (миграции)
-- ===============================================

-- 1. Схемы
DROP SCHEMA IF EXISTS stg CASCADE;
DROP SCHEMA IF EXISTS ods CASCADE;
DROP SCHEMA IF EXISTS dds CASCADE;

CREATE SCHEMA stg;
CREATE SCHEMA ods;
CREATE SCHEMA dds;

-- 2. STG: сырые данные (как пришли)
CREATE TABLE stg.customers_raw (
    customer_id TEXT,
    email       TEXT,
    phone       TEXT,
    city        TEXT,
    _load_ts    TIMESTAMP DEFAULT NOW()
);

CREATE TABLE stg.orders_raw (
    order_id    TEXT,
    order_date  TEXT,
    customer_id TEXT
);

CREATE TABLE stg.order_items_raw (
    order_item_id   TEXT,
    order_id        TEXT,
    product_id      TEXT,
    qty             TEXT,
    price_at_sale   TEXT
);

CREATE TABLE stg.products_raw (
    product_id TEXT,
    name       TEXT
);

-- 3. ODS: очищенные данные
CREATE TABLE ods.customers (
    customer_id INT,
    email       VARCHAR(100),
    phone       VARCHAR(20),
    city        VARCHAR(50)
);

CREATE TABLE ods.orders (
    order_id    INT,
    order_date  DATE,
    customer_id INT
);

CREATE TABLE ods.order_items (
    order_item_id INT,
    order_id      INT,
    product_id    INT,
    qty           INT,
    price_at_sale NUMERIC(10,2)
);

CREATE TABLE ods.products (
    product_id INT,
    name       VARCHAR(100)
);

-- Первичные ключи в ODS (для ускорения и валидации)
ALTER TABLE ods.customers  ADD PRIMARY KEY (customer_id);
ALTER TABLE ods.orders     ADD PRIMARY KEY (order_id);
ALTER TABLE ods.order_items ADD PRIMARY KEY (order_item_id);
ALTER TABLE ods.products   ADD PRIMARY KEY (product_id);

-- 4. DDS: интегрированная модель

-- dim_date: справочник дат (без первичного ключа — генерируется)
CREATE TABLE dds.dim_date (
    date_key     INT PRIMARY KEY,
    date_actual  DATE NOT NULL,
    year         SMALLINT,
    quarter      SMALLINT,
    month        SMALLINT,
    day          SMALLINT,
    weekday_name VARCHAR(10),
    weekday_num  SMALLINT,
    is_first_week BOOLEAN
);

-- dim_product: измерение "Товар"
CREATE TABLE dds.dim_product (
    product_sk   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_bk   INT NOT NULL,
    product_name VARCHAR(100) NOT NULL
);

-- dim_customer: измерение "Клиент" с SCD Type 2
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

-- fact_sales: факт "Продажи"
CREATE TABLE dds.fact_sales (
    sale_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_sk  BIGINT NOT NULL,
    product_sk   BIGINT NOT NULL,
    date_key     INT NOT NULL,
    quantity     INT NOT NULL CHECK (quantity > 0),
    amount       NUMERIC(18,2) NOT NULL CHECK (amount >= 0)
);

-- Внешние ключи (опционально — в продакшене часто отключают ради скорости)
ALTER TABLE dds.fact_sales 
    ADD CONSTRAINT fk_fact_customer FOREIGN KEY (customer_sk) REFERENCES dds.dim_customer(customer_sk),
    ADD CONSTRAINT fk_fact_product  FOREIGN KEY (product_sk)  REFERENCES dds.dim_product(product_sk),
    ADD CONSTRAINT fk_fact_date     FOREIGN KEY (date_key)    REFERENCES dds.dim_date(date_key);
