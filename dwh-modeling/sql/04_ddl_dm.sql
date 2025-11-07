-- ===============================================
-- DDL: Data Marts (DM)
-- Слой "готовых решений" — для BI, отчётов, API
-- ===============================================

DROP SCHEMA IF EXISTS dm CASCADE;
CREATE SCHEMA dm;

-- Витрина: ежедневные продажи по товарам и клиентам
-- Гранулярность: 1 строка = 1 день × 1 товар × 1 сегмент клиента
CREATE TABLE dm.mart_daily_sales (
    date_actual      DATE NOT NULL,
    product_name     VARCHAR(100) NOT NULL,
    customer_segment VARCHAR(20) NOT NULL,  -- напр. 'Premium', 'Basic'
    total_qty        INT NOT NULL,
    total_revenue    NUMERIC(18,2) NOT NULL
);

-- Витрина: 360°-портрет клиента (lifetime value)
CREATE TABLE dm.mart_customer_360 (
    customer_bk      INT NOT NULL,
    first_order_date DATE,
    last_order_date  DATE,
    total_orders     INT NOT NULL,
    total_items      INT NOT NULL,
    lifetime_value   NUMERIC(18,2) NOT NULL,
    last_email       VARCHAR(100),
    last_city        VARCHAR(50)
);

-- Индексы для ускорения BI (опционально, но рекомендовано)
CREATE INDEX ON dm.mart_daily_sales (date_actual);
CREATE INDEX ON dm.mart_daily_sales (product_name);
CREATE INDEX ON dm.mart_customer_360 (customer_bk);
