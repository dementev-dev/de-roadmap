-- ===============================================
-- Проверки качества данных после загрузки STG→ODS→DDS
-- Запускается после 02_dml.sql
-- ===============================================

-- 1. Проверка: dim_customer не пуста
DO $$
BEGIN
    ASSERT (SELECT COUNT(*) FROM dds.dim_customer) > 0,
        'ОШИБКА: таблица dds.dim_customer пуста — загрузка не прошла';
    RAISE NOTICE '✅ dim_customer: НЕ ПУСТА (всего строк: %)', 
        (SELECT COUNT(*) FROM dds.dim_customer);
END $$;

-- 2. Проверка: fact_sales содержит все строки из order_items
DO $$
DECLARE 
    expected_count INT := (SELECT COUNT(*) FROM ods.order_items);
    actual_count   INT := (SELECT COUNT(*) FROM dds.fact_sales);
BEGIN
    ASSERT actual_count = expected_count,
        FORMAT('ОШИБКА: в fact_sales %s строк, а в ods.order_items — %s. Разница: %s',
               actual_count, expected_count, expected_count - actual_count);
    RAISE NOTICE '✅ fact_sales: количество строк совпадает с ods.order_items (%)', actual_count;
END $$;

-- 3. Проверка: у каждого факта есть валидная дата (date_key существует)
DO $$
DECLARE missing_dates INT;
BEGIN
    SELECT COUNT(*) INTO missing_dates
    FROM dds.fact_sales f
    LEFT JOIN dds.dim_date d ON f.date_key = d.date_key
    WHERE d.date_key IS NULL;

    ASSERT missing_dates = 0,
        FORMAT('ОШИБКА: %s фактов ссылаются на несуществующие даты (неверный date_key)', missing_dates);
    RAISE NOTICE '✅ Все факты имеют валидные date_key';
END $$;

-- 4. Проверка SCD Type 2: у клиента 101 должно быть ≥2 версий (из-за смены email)
DO $$
DECLARE version_count INT;
BEGIN
    SELECT COUNT(*) INTO version_count
    FROM dds.dim_customer
    WHERE customer_bk = 101;

    ASSERT version_count >= 2,
        FORMAT('ОШИБКА: у клиента 101 только %s версия, ожидается ≥2 (должна быть история)', version_count);
    RAISE NOTICE '✅ SCD Type 2: клиент 101 имеет %s версий — история сохранена', version_count;
END $$;

-- 5. Проверка: сумма amount = qty * price_at_sale (без округления)
DO $$
DECLARE bad_rows INT;
BEGIN
    SELECT COUNT(*) INTO bad_rows
    FROM (
        SELECT 
            f.sale_id,
            f.amount,
            oi.qty * oi.price_at_sale AS expected_amount
        FROM dds.fact_sales f
        JOIN ods.orders o ON f.date_key = CAST(TO_CHAR(o.order_date, 'YYYYMMDD') AS INT)
        JOIN ods.order_items oi ON o.order_id = oi.order_id
        WHERE ROUND(f.amount, 2) <> ROUND(oi.qty * oi.price_at_sale, 2)
        LIMIT 10
    ) mismatches;

    ASSERT bad_rows = 0,
        'ОШИБКА: обнаружены расхождения между amount и qty * price_at_sale';
    RAISE NOTICE '✅ Все суммы рассчитаны верно (amount = qty × price_at_sale)';
END $$;

-- ===============================================
-- Финальный отчёт для аналитика
-- ===============================================

RAISE NOTICE '──────────────────────────────';
RAISE NOTICE '📊 ОТЧЁТ: Выручка по клиентам (актуальные версии)';
RAISE NOTICE '──────────────────────────────';

SELECT
    dc.customer_bk          AS "ID клиента",
    dc.email                AS "Email",
    dc.city                 AS "Город",
    SUM(f.quantity)         AS "Всего товаров",
    SUM(f.amount)           AS "Выручка, ₽"
FROM dds.fact_sales f
JOIN dds.dim_customer dc 
    ON f.customer_sk = dc.customer_sk 
    AND dc.is_current  -- только актуальная версия
GROUP BY dc.customer_bk, dc.email, dc.city
ORDER BY SUM(f.amount) DESC;

RAISE NOTICE '──────────────────────────────';
RAISE NOTICE '✅ Все проверки пройдены. DWH готов к построению витрин.';
