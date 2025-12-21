-- ===============================================
-- Проверки качества данных после загрузки STG→ODS→DDS
-- Запускается после 02_dml_stg-dds.sql (и, при необходимости, 03_demo_increment.sql)
-- ===============================================

-- 1. Проверка: dim_customer не пуста
DO $$
BEGIN
    ASSERT (SELECT COUNT(*) FROM dds.dim_customer) > 0,
        'ОШИБКА: таблица dds.dim_customer пуста — загрузка не прошла';
    RAISE NOTICE '✅ dim_customer: НЕ ПУСТА (всего строк: %)', 
        (SELECT COUNT(*) FROM dds.dim_customer);
END $$;

-- 2. Проверка: каждая строка из ODS попала в DDS-факт
-- Сравниваем количество строк в ods.order_items и dds.fact_sales
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

-- 3. Проверка SCD2 (Type 2): у клиента 101 должно быть ≥2 версий (из-за смены email)
DO $$
DECLARE version_count INT;
BEGIN
    SELECT COUNT(*) INTO version_count
    FROM dds.dim_customer
    WHERE customer_bk = 101;
    --
    ASSERT version_count >= 2,
        FORMAT('ОШИБКА: у клиента 101 только %s версия, ожидается ≥2 (должна быть история)', version_count);
    RAISE NOTICE '✅ SCD2: клиент 101 имеет % версий — история сохранена', version_count;
END $$;

-- 4. Проверка SCD2 (Type 2): у каждого клиента ровно одна актуальная версия (valid_to IS NULL)
DO $$
DECLARE
    customers_cnt BIGINT;
    current_cnt   BIGINT;
BEGIN
    SELECT COUNT(DISTINCT customer_bk) INTO customers_cnt FROM dds.dim_customer;
    SELECT COUNT(*) INTO current_cnt
    FROM dds.dim_customer
    WHERE valid_to IS NULL;
    --
    ASSERT current_cnt = customers_cnt,
        FORMAT('ОШИБКА: актуальных строк %s, а уникальных клиентов %s (ожидается 1 current на клиента)',
               current_cnt, customers_cnt);
    RAISE NOTICE '✅ SCD2: current-строки = количеству клиентов (%)', current_cnt;
END $$;

-- 5. Проверка SCD2 (Type 2): периоды корректны (valid_to > valid_from или valid_to IS NULL)
DO $$
BEGIN
    ASSERT NOT EXISTS (
        SELECT 1
        FROM dds.dim_customer
        WHERE valid_to IS NOT NULL
          AND valid_to <= valid_from
    ),
    'ОШИБКА: найдены строки dim_customer с некорректным периодом (valid_to <= valid_from)';
    RAISE NOTICE '✅ SCD2: периоды valid_from/valid_to корректны';
END $$;
