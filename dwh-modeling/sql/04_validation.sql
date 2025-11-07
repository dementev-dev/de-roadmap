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

-- 3. Проверка: у каждого факта есть валидная дата (date_key существует)
DO $$
DECLARE 
    expected_count bigint;
    actual_count   bigint;
BEGIN
    SELECT COUNT(*) INTO expected_count FROM ods.order_items;
    SELECT COUNT(*) INTO actual_count   FROM dds.fact_sales;
    --
    ASSERT actual_count = expected_count,
           format('ОШИБКА: в fact_sales %s строк, а в ods.order_items — %s. Разница: %s',
                  actual_count, expected_count, expected_count - actual_count);
    --
    RAISE NOTICE '✅ fact_sales: количество строк совпадает с ods.order_items (%)', actual_count;
END $$;

-- 4. Проверка SCD Type 2: у клиента 101 должно быть ≥2 версий (из-за смены email)
DO $$
DECLARE version_count INT;
BEGIN
    SELECT COUNT(*) INTO version_count
    FROM dds.dim_customer
    WHERE customer_bk = 101;
    --
    ASSERT version_count >= 2,
        FORMAT('ОШИБКА: у клиента 101 только %s версия, ожидается ≥2 (должна быть история)', version_count);
    RAISE NOTICE '✅ SCD Type 2: клиент 101 имеет %s версий — история сохранена', version_count;
END $$;

