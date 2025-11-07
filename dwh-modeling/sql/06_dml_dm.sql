-- ===============================================
-- DML: построение Data Marts из DDS
-- Идемпотентно: можно пересобирать в любое время
-- ===============================================

-- 1. Очистка (full refresh — для простоты; в продакшене — incremental)
TRUNCATE dm.mart_daily_sales, dm.mart_customer_360;

-- 2. mart_daily_sales: агрегация по дням
-- Используем актуальные версии измерений (is_current = true)
-- Для кого: Маркетолог, продакт-аналитик
-- Пример использования: «Как менялись продажи Phone в сегменте Premium по дням?»
INSERT INTO dm.mart_daily_sales (
    date_actual, product_name, customer_segment, total_qty, total_revenue
)
SELECT
    d.date_actual,
    p.product_name,
    -- Простая сегментация по выручке за заказ
    CASE 
        WHEN f.amount >= 200 THEN 'Premium'
        ELSE 'Basic'
    END AS customer_segment,
    SUM(f.quantity) AS total_qty,
    SUM(f.amount) AS total_revenue
FROM dds.fact_sales f
JOIN dds.dim_date d ON f.date_key = d.date_key
JOIN dds.dim_product p ON f.product_sk = p.product_sk
JOIN dds.dim_customer c ON f.customer_sk = c.customer_sk AND c.is_current
GROUP BY d.date_actual, p.product_name, 
         CASE WHEN f.amount >= 200 THEN 'Premium' ELSE 'Basic' END;

-- 3. mart_customer_360: lifetime-портрет
-- Здесь — НЕ используем is_current! Нам нужна вся история для расчёта LTV
-- Для кого: CRM-менеджер, retention-спец
-- Пример использования: «Найти клиентов с LTV > 250 ₽ и email из Москвы для email-рассылки»
«Найти клиентов с LTV > 250 ₽ и email из Москвы для email-рассылки»
INSERT INTO dm.mart_customer_360 (
    customer_bk, first_order_date, last_order_date,
    total_orders, total_items, lifetime_value,
    last_email, last_city
)
SELECT
    c.customer_bk,
    MIN(d.date_actual) AS first_order_date,
    MAX(d.date_actual) AS last_order_date,
    COUNT(DISTINCT f.sale_id) AS total_orders,
    SUM(f.quantity) AS total_items,
    SUM(f.amount) AS lifetime_value,
    -- Берём email и город из самой свежей версии клиента
    (SELECT email FROM dds.dim_customer c2 
     WHERE c2.customer_bk = c.customer_bk 
     ORDER BY c2.valid_from DESC 
     LIMIT 1) AS last_email,
    (SELECT city FROM dds.dim_customer c2 
     WHERE c2.customer_bk = c.customer_bk 
     ORDER BY c2.valid_from DESC 
     LIMIT 1) AS last_city
FROM dds.fact_sales f
JOIN dds.dim_date d ON f.date_key = d.date_key
JOIN dds.dim_customer c ON f.customer_sk = c.customer_sk
-- ⚠️ Важно: здесь НЕ фильтруем по is_current — нужна вся история!
GROUP BY c.customer_bk;

-- 4. Дополнительно: материализованное представление (альтернатива таблице)
-- В PG 12+ можно использовать MATERIALIZED VIEW — обновляется по команде REFRESH
-- CREATE MATERIALIZED VIEW dm.mv_monthly_sales AS
-- SELECT ... (аналогично)
