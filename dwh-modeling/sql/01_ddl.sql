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
    customer_id TEXT,                    -- может быть строкой или числом
    email       TEXT,
    phone       TEXT,
    city        TEXT,
    _load_id    TEXT,                    -- идентификатор загрузки (обязательно!)
    _load_ts    TIMESTAMP DEFAULT NOW(), -- время получения в DWH
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
    customer_id INT NOT NULL,      -- привели к INT
    email       VARCHAR(100),
    phone       VARCHAR(20),
    city        VARCHAR(50),
    _load_id    TEXT NOT NULL,     -- сохраняем для отладки и SCD
    _load_ts    TIMESTAMP NOT NULL -- время загрузки (копия из STG)
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
    customer_sk   BIGSERIAL PRIMARY KEY,
    customer_bk   INT        NOT NULL,                -- бизнес-ключ
    email         TEXT,
    phone         TEXT,
    city          TEXT,
    hashdiff      TEXT        NOT NULL,               -- md5 по нормализованным атрибутам
    valid_from    TIMESTAMP   NOT NULL,
    valid_to      TIMESTAMP   NOT NULL,
    is_current    BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP   NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMP   NOT NULL DEFAULT NOW()
);

-- одна версия на момент времени
ALTER TABLE dds.dim_customer
    ADD CONSTRAINT uq_dim_customer_bk_from UNIQUE (customer_bk, valid_from);    -- dim_product: измерение "

-- ускорители
CREATE INDEX ix_dim_customer_bk_current ON dds.dim_customer (customer_bk) WHERE is_current;
CREATE INDEX ix_dim_customer_bk_from_to ON dds.dim_customer (customer_bk, valid_from, valid_to);

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


-- Через md5 по нормализованным атрибутам
CREATE OR REPLACE FUNCTION dds.customer_hash(email TEXT, phone TEXT, city TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
  SELECT md5(
    concat_ws('||',
      lower(coalesce(trim(email), '')),
      lower(coalesce(trim(phone), '')),
      lower(coalesce(trim(city),  ''))
    )
  );
$$;
