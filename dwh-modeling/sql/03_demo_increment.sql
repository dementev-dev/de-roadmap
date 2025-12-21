-- ===============================================
-- 03_demo_increment.sql
-- Имитация новых событий + инкрементальный SCD2
-- ===============================================

-- 0. Новые события в STG (пример)
INSERT INTO stg.customers_raw (_load_id, _load_ts, event_ts, customer_id, email, phone, city) VALUES
('batch_20241101_0800', '2024-11-01 08:00', '2024-11-01',  '101','b@ex.com','700','Москва'),          -- город вернулся
('batch_20240310_0800', '2024-03-10 08:00', '2024-03-10',  '103','d@ex.com','702','Казань');          -- новый клиент

-- 1) UPSERT в ODS последнего снимка по BK
WITH src AS (
  SELECT
      s.customer_id::INT                                     AS customer_id,
      NULLIF(trim(s.email), '')                              AS email,
      NULLIF(trim(s.phone), '')                              AS phone,
      NULLIF(trim(s.city),  '')                              AS city,
      NULLIF(s.event_ts,'')::timestamp                       AS event_ts,
      s._load_id,
      s._load_ts,
      COALESCE(NULLIF(s.event_ts,'')::timestamp, s._load_ts) AS eff_ts
  FROM stg.customers_raw s
  WHERE s.customer_id ~ '^\d+$'
),
ranked AS (
  SELECT
         customer_id, email, phone, city, event_ts, _load_id, _load_ts,
         row_number() OVER (PARTITION BY customer_id ORDER BY eff_ts DESC, _load_ts DESC) AS rn
  FROM src
)
INSERT INTO ods.customers (customer_id, email, phone, city, event_ts, _load_id, _load_ts)
SELECT customer_id, email, phone, city, event_ts, _load_id, _load_ts
FROM ranked
WHERE rn = 1
ON CONFLICT (customer_id) DO UPDATE
SET email   = EXCLUDED.email,
    phone   = EXCLUDED.phone,
    city    = EXCLUDED.city,
    event_ts= EXCLUDED.event_ts,
    _load_id= EXCLUDED._load_id,
    _load_ts= EXCLUDED._load_ts
-- апдейтим только если пришло более «свежее» событие
WHERE COALESCE(EXCLUDED.event_ts, EXCLUDED._load_ts) >
      COALESCE(ods.customers.event_ts, ods.customers._load_ts);

-- 2) Инкрементальное SCD2 из ODS (в одной транзакции, по последнему снимку в ODS)
--    Канон для курса: daily-grain, интервалы [valid_from, valid_to), текущая версия = valid_to IS NULL
--    Предполагаем, что для клиента нет нескольких изменений в один день.
BEGIN;
    -- 2.1) Закрываем предыдущую актуальную версию (только если реально изменились атрибуты)
    WITH delta AS (
      SELECT
        c.customer_id                                         AS customer_bk,
        c.email, c.phone, c.city,
        COALESCE(c.event_ts::date, c._load_ts::date)          AS eff_date,
        dds.customer_hash(c.email, c.phone, c.city)           AS hashdiff
      FROM ods.customers c
    ),
    current AS (
      SELECT d.*
      FROM dds.dim_customer d
      WHERE d.valid_to IS NULL
    )
    UPDATE dds.dim_customer d
       SET valid_to   = x.eff_date,
           updated_at = now()
      FROM (
        SELECT
          t.customer_bk,
          t.eff_date,
          c.customer_sk
        FROM delta t
        JOIN current c
          ON c.customer_bk = t.customer_bk
        WHERE c.hashdiff <> t.hashdiff
          AND t.eff_date > c.valid_from
      ) x
     WHERE d.customer_sk = x.customer_sk
       AND d.valid_to IS NULL;

    -- 2.2) Вставляем новую версию (только если новая или изменившаяся)
    WITH delta AS (
      SELECT
        c.customer_id                                         AS customer_bk,
        c.email, c.phone, c.city,
        COALESCE(c.event_ts::date, c._load_ts::date)          AS eff_date,
        dds.customer_hash(c.email, c.phone, c.city)           AS hashdiff
      FROM ods.customers c
    ),
    current AS (
      SELECT d.*
      FROM dds.dim_customer d
      WHERE d.valid_to IS NULL
    ),
    to_insert AS (
      SELECT
        t.customer_bk,
        t.email,
        t.phone,
        t.city,
        t.hashdiff,
        t.eff_date
      FROM delta t
      LEFT JOIN current c
        ON c.customer_bk = t.customer_bk
      WHERE c.customer_sk IS NULL
         OR (c.hashdiff <> t.hashdiff AND t.eff_date > c.valid_from)
    )
    INSERT INTO dds.dim_customer (
      customer_bk, email, phone, city, hashdiff,
      valid_from, valid_to,
      created_at, updated_at
    )
    SELECT
      t.customer_bk, t.email, t.phone, t.city, t.hashdiff,
      t.eff_date, NULL,
      now(), now()
    FROM to_insert t
    WHERE NOT EXISTS (
      SELECT 1
      FROM dds.dim_customer d
      WHERE d.customer_bk = t.customer_bk
        AND d.valid_from = t.eff_date
    );
COMMIT;

-- (факты можно не перезаливать — даты заказов не поменялись)
