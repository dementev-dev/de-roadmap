-- ===============================================
-- 03_demo_increment.sql
-- Имитация новых событий + инкрементальный SCD2
-- ===============================================

-- 0. Новые события в STG (пример)
INSERT INTO stg.customers_raw (_load_id, _load_ts, event_ts, customer_id, email, phone, city) VALUES
('batch_20250406_0900', '2025-04-06 09:00', NULL,  '101','b@ex.com','700','Москва'),          -- город вернулся
('batch_20250406_1200', '2025-04-06 12:00', NULL,  '103','d@ex.com','702','Казань');          -- новый клиент

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
      COALESCE(NULLIF(s.event_ts,'')::timestamp, s._load_ts,
               to_timestamp(regexp_replace(s._load_id,'^batch_',''),'YYYYMMDD_HH24MI')) AS eff_ts
  FROM stg.customers_raw s
  WHERE s.customer_id ~ '^\d+$'
),
last_per_bk AS (
  SELECT DISTINCT ON (customer_id)
         customer_id, email, phone, city, event_ts, _load_id, _load_ts, eff_ts
  FROM src
  ORDER BY customer_id, eff_ts DESC, _load_ts DESC
)
INSERT INTO ods.customers (customer_id, email, phone, city, event_ts, _load_id, _load_ts)
SELECT customer_id, email, phone, city, event_ts, _load_id, _load_ts
FROM last_per_bk
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

-- 2) Инкрементальное SCD2 из ODS
BEGIN;
    WITH delta AS (
      SELECT
        c.customer_id                                         AS customer_bk,
        c.email, c.phone, c.city,
        COALESCE(c.event_ts, c._load_ts)                      AS eff_ts,
        dds.customer_hash(c.email, c.phone, c.city)           AS hashdiff
      FROM ods.customers c
    ),
    expired AS (
      UPDATE dds.dim_customer d
         SET valid_to   = LEAST(d.valid_to, delta.eff_ts - interval '1 second'),
             is_current = FALSE,
             updated_at = now()
      FROM delta
      WHERE d.customer_bk = delta.customer_bk
        AND d.is_current = TRUE
        AND d.hashdiff  <> delta.hashdiff
        AND delta.eff_ts >= d.valid_from
      RETURNING d.customer_bk
    )
    INSERT INTO dds.dim_customer (
      customer_bk, email, phone, city, hashdiff,
      valid_from,                                                                 valid_to,
      is_current, created_at, updated_at
    )
    SELECT
      s.customer_bk, s.email, s.phone, s.city, s.hashdiff,
      CASE WHEN d.customer_bk IS NULL THEN timestamp '1900-01-01' ELSE s.eff_ts END AS valid_from,
      timestamp '9999-12-31',
      TRUE, now(), now()
    FROM delta s
    LEFT JOIN dds.dim_customer d
      ON d.customer_bk = s.customer_bk AND d.is_current = TRUE
    WHERE d.customer_bk IS NULL      -- новый BK
       OR d.hashdiff <> s.hashdiff   -- изменившийся BK
    ON CONFLICT (customer_bk, valid_from) DO NOTHING;
COMMIT;

-- (факты можно не перезаливать — даты заказов не поменялись)
