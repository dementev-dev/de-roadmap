-- ===============================================
-- DML: построение Data Marts из DDS
-- Идемпотентно: можно пересобирать в любое время
-- ===============================================

-- 1. Очистка (full refresh — для простоты; в продакшене — incremental)
TRUNCATE dm.mart_daily_sales, dm.mart_customer_360;

-- 2. mart_daily_sales: продажи по датам и товарам
-- Одна строка = дата × товар × простой сегмент заказа
INSERT INTO dm.mart_daily_sales (
    date_actual, product_name, customer_segment, total_qty, total_revenue
)
SELECT
    d.date_actual,
    p.product_name,
    -- Делим заказы на Premium / Basic по сумме
    CASE 
        WHEN f.amount >= 200 THEN 'Premium'
        ELSE 'Basic'
    END AS customer_segment,
    SUM(f.quantity) AS total_qty,
    SUM(f.amount) AS total_revenue
FROM dds.fact_sales f
JOIN dds.dim_date d ON f.date_key = d.date_key
JOIN dds.dim_product p ON f.product_sk = p.product_sk
JOIN dds.dim_customer c ON f.customer_sk = c.customer_sk  -- факт уже ссылается на нужную версию клиента
GROUP BY d.date_actual, p.product_name, 
         CASE WHEN f.amount >= 200 THEN 'Premium' ELSE 'Basic' END;

-- 3. mart_customer_360: 360‑портрет клиента
-- Одна строка = один клиент
-- Считаем суммы по всей истории его покупок
INSERT INTO dm.mart_customer_360 (
    customer_bk, first_order_date, last_order_date,
    total_orders, total_items, lifetime_value,
    last_email, last_city
)
SELECT
    c.customer_bk,
    MIN(d.date_actual) AS first_order_date,
    MAX(d.date_actual) AS last_order_date,
    COUNT(DISTINCT f.sale_id) AS total_orders,  -- считаем строки факта (продажи), не бизнес-заказы
    SUM(f.quantity) AS total_items,
    SUM(f.amount) AS lifetime_value,
    -- Берём самый свежий email и город клиента
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
-- Здесь не фильтруем по valid_to: нужна вся история фактов
GROUP BY c.customer_bk;
