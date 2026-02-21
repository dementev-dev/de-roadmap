-- ===============================================
-- 09_dml_hw_customer_status_solution.sql
-- Решение домашки: статусы клиента (STG -> ODS -> DDS SCD2 -> DM)
--
-- Это ЭТАЛОННОЕ РЕШЕНИЕ. Если вы ещё не пробовали решить домашку сами -
-- вернитесь к заданию (Homework_Customer_Status_DDS_DM.md) и шаблону (08_dml_hw_customer_status_template.sql).
-- Основная ценность задания - в самостоятельном разборе.
--
-- Что делает этот файл:
--   1) Перекладывает события статусов в ODS (приводит типы, чистит пустое).
--   2) Строит DDS-измерение со "встроенной историей" (SCD2): периоды valid_from/valid_to.
--   3) Загружает инкрементальную порцию событий и обновляет ODS + DDS.
--   4) Собирает простую витрину в DM: сколько клиентов в каком статусе по дням.
--
-- Как запускать:
--   - для первого знакомства можно запускать файл целиком;
--   - если хотите потренировать инкремент (п.3): добавьте свои события -> запустите блок 3 ещё раз.
--
-- Важно:
--   - здесь часто используется TRUNCATE (полная очистка), чтобы было легко повторять домашку;
--   - в реальном DWH так делают не всегда, но для обучения это удобнее.
--
-- Предусловия (DDL + данные в STG):
--   1) dwh-modeling/sql/01_ddl_stg-dds.sql
--   2) dwh-modeling/sql/02_dml_stg-dds.sql  (нужен dim_date)
--   3) dwh-modeling/sql/05_ddl_dm.sql
--   4) dwh-modeling/sql/07_ddl_hw_customer_status.sql
--   5) stg.customer_status_raw заполнена (см. dwh-modeling/Homework_Customer_Status_DDS_DM.md)
-- ===============================================

-- ==========================================================
-- 1) ODS: очистка и типизация (full refresh)
-- ==========================================================

-- Идея:
--   - STG хранит "как пришло" (обычно TEXT);
--   - ODS хранит "аккуратно": правильные типы + простая чистка.
-- Для простоты пересобираем ODS с нуля.
--
-- Обратите внимание: ods.customer_status хранит ВСЕ события (PK = customer_id + event_ts),
-- а не только последнее состояние, как ods.customers (PK = customer_id).
-- Причина: источник данных здесь - поток событий ("статус стал X в момент Y"),
-- а не снимок ("вот текущие данные клиента"). ODS сохраняет природу источника:
-- снимок остаётся снимком, события остаются событиями.
-- Благодаря этому full backfill SCD2 (блок 2) строится прямо из ODS, а не из STG.

TRUNCATE ods.customer_status;

INSERT INTO ods.customer_status (
    customer_id, status, event_ts, _load_id, _load_ts
)
SELECT
    s.customer_id::INT                                           AS customer_id,
    NULLIF(trim(s.status), '')                                   AS status,
    NULLIF(trim(s.event_ts), '')::TIMESTAMP                      AS event_ts,
    s._load_id,
    COALESCE(s._load_ts, now())                                  AS _load_ts
FROM stg.customer_status_raw s
WHERE s.customer_id ~ '^\d+$'
  AND NULLIF(trim(s.event_ts), '') IS NOT NULL
  AND NULLIF(trim(s.status), '') IS NOT NULL;

-- Проверка: что получилось в ODS
SELECT 'ods.customer_status count = ' || COUNT(*) FROM ods.customer_status;
SELECT * FROM ods.customer_status ORDER BY customer_id, event_ts;

-- ==========================================================
-- 2) DDS: начальная загрузка SCD2 (full refresh)
-- ==========================================================

-- Идея SCD2 простыми словами:
--   - одна строка = один период, когда статус был одним и тем же;
--   - valid_from = с какого дня статус "начался";
--   - valid_to = с какого дня статус "закончился" (NULL = текущий статус);
--   - интервалы считаем так: [valid_from, valid_to) (valid_to не включаем).
--   - чтобы найти статус "на дату D":
--     D >= valid_from AND (valid_to IS NULL OR D < valid_to)
--
-- Упрощение для домашки:
--   - считаем, что у клиента нет двух разных смен статуса в один день.

TRUNCATE dds.dim_customer_status;

WITH src AS (
    -- src: события из ODS + "контрольная сумма" статуса.
    -- Так проще проверять, поменялся статус или остался тем же.
    SELECT
        customer_id                                              AS customer_bk,
        status,
        event_ts,
        md5(lower(coalesce(status, '')))                         AS hashdiff
    FROM ods.customer_status
),
ordered AS (
    -- ordered: для каждого клиента смотрим "какая версия была до этого" (LAG)
    SELECT
        *,
        lag(hashdiff) OVER (
            PARTITION BY customer_bk
            ORDER BY event_ts
        )                                                        AS prev_hash
    FROM src
),
changes AS (
    -- changes: оставляем только первое состояние и реальные изменения статуса
    SELECT *
    FROM ordered
    WHERE prev_hash IS DISTINCT FROM hashdiff OR prev_hash IS NULL
),
framed AS (
    -- framed: превращаем изменения в периоды (valid_to = дата следующего события через LEAD)
    SELECT
        customer_bk,
        status,
        hashdiff,
        event_ts::DATE                                           AS valid_from,
        lead(event_ts::DATE) OVER (
            PARTITION BY customer_bk
            ORDER BY event_ts
        )                                                        AS valid_to
    FROM changes
)
INSERT INTO dds.dim_customer_status (
    customer_bk, status, hashdiff,
    valid_from, valid_to,
    created_at, updated_at
)
SELECT
    customer_bk, status, hashdiff,
    valid_from, valid_to,
    now(), now()
FROM framed
ORDER BY customer_bk, valid_from;

-- Проверка: периоды в DDS (у клиента 101 должно быть 4 строки: new -> active -> vip -> churned)
SELECT 'dim_customer_status count = ' || COUNT(*) FROM dds.dim_customer_status;
SELECT * FROM dds.dim_customer_status ORDER BY customer_bk, valid_from;

-- ==========================================================
-- 3) Инкрементальная загрузка: STG -> ODS -> DDS
-- ==========================================================

-- Имитируем приход новой порции событий (customer_status_events_increment.csv):
--   - клиент 101: churned -> active (вернулся)
--   - клиент 102: churned -> active
--   - клиент 103: new -> active
--   - клиент 104: новый клиент, статус new

-- 3.0) Новые события в STG
-- При повторном запуске эти строки добавятся в STG ещё раз (дубли).
-- Для демо это не страшно: ODS-вставка ниже использует ON CONFLICT DO NOTHING,
-- а SCD2-блок защищён от повторных вставок через NOT EXISTS.
-- В продакшене STG обычно очищается перед каждой загрузкой (TRUNCATE / партиция по дате).
INSERT INTO stg.customer_status_raw (customer_id, status, event_ts, _load_id, _load_ts) VALUES
('101','active','2024-11-15 09:00:00','batch_20241115_1000','2024-11-15 10:00:00'),
('102','active','2024-05-05 09:30:00','batch_20240505_1000','2024-05-05 10:00:00'),
('103','active','2024-03-20 12:00:00','batch_20240320_1300','2024-03-20 13:00:00'),
('104','new',   '2024-06-01 08:00:00','batch_20240601_0900','2024-06-01 09:00:00');

-- 3.1) UPSERT в ODS: добавляем новые события (не трогаем старые)
--   PK в ods.customer_status = (customer_id, event_ts), поэтому каждое уникальное
--   событие встаёт отдельной строкой. Дубли (одинаковый customer_id + event_ts) игнорируем.
INSERT INTO ods.customer_status (
    customer_id, status, event_ts, _load_id, _load_ts
)
SELECT
    s.customer_id::INT,
    NULLIF(trim(s.status), ''),
    NULLIF(trim(s.event_ts), '')::TIMESTAMP,
    s._load_id,
    COALESCE(s._load_ts, now())
FROM stg.customer_status_raw s
WHERE s.customer_id ~ '^\d+$'
  AND NULLIF(trim(s.event_ts), '') IS NOT NULL
  AND NULLIF(trim(s.status), '') IS NOT NULL
ON CONFLICT (customer_id, event_ts) DO NOTHING;

-- Проверка: в ODS должны появиться новые строки
SELECT 'ods.customer_status after increment = ' || COUNT(*) FROM ods.customer_status;

-- 3.2) Инкрементальное обновление DDS (SCD2)
-- Идея:
--   1) берём по каждому клиенту самое позднее событие из ODS;
--   2) сравниваем с текущей версией в DDS (valid_to IS NULL);
--   3) если статус изменился - закрываем старую версию и вставляем новую.
--
-- Ограничение учебного варианта:
--   - если добавили событие "задним числом" со старой датой, этот блок не пересоберёт всю историю.
--     Для такого кейса обычно делают full refresh (блок 2).

BEGIN;
    -- 3.2a) Закрываем предыдущую актуальную версию
    WITH ranked AS (
        -- ranked: выбираем "самое свежее" событие на клиента
        SELECT
            customer_id                                          AS customer_bk,
            status,
            event_ts::DATE                                       AS eff_date,
            md5(lower(coalesce(status, '')))                     AS hashdiff,
            row_number() OVER (
                PARTITION BY customer_id
                ORDER BY event_ts DESC, _load_ts DESC
            )                                                    AS rn
        FROM ods.customer_status
        WHERE event_ts IS NOT NULL
    ),
    delta AS (
        -- delta: ровно одна строка на клиента (самое свежее событие)
        SELECT * FROM ranked WHERE rn = 1
    ),
    current_ver AS (
        -- current_ver: текущие версии в DDS (valid_to IS NULL)
        SELECT d.*
        FROM dds.dim_customer_status d
        WHERE d.valid_to IS NULL
    )
    UPDATE dds.dim_customer_status d
       SET valid_to   = x.eff_date,
           updated_at = now()
      FROM (
        -- x: кого "закрываем":
        -- клиент уже есть в DDS, и статус действительно изменился.
        SELECT
            t.customer_bk,
            t.eff_date,
            c.customer_status_sk
        FROM delta t
        JOIN current_ver c
          ON c.customer_bk = t.customer_bk
        WHERE c.hashdiff <> t.hashdiff
          AND t.eff_date > c.valid_from  -- не создаём период нулевой/отрицательной длины
      ) x
     WHERE d.customer_status_sk = x.customer_status_sk
       AND d.valid_to IS NULL;

    -- 3.2b) Вставляем новую версию
    WITH ranked AS (
        -- ranked/delta/current_ver повторяем отдельно, чтобы блок INSERT читался отдельно от UPDATE
        SELECT
            customer_id                                          AS customer_bk,
            status,
            event_ts::DATE                                       AS eff_date,
            md5(lower(coalesce(status, '')))                     AS hashdiff,
            row_number() OVER (
                PARTITION BY customer_id
                ORDER BY event_ts DESC, _load_ts DESC
            )                                                    AS rn
        FROM ods.customer_status
        WHERE event_ts IS NOT NULL
    ),
    delta AS (
        SELECT * FROM ranked WHERE rn = 1
    ),
    current_ver AS (
        SELECT d.*
        FROM dds.dim_customer_status d
        WHERE d.valid_to IS NULL
    ),
    to_insert AS (
        -- to_insert: кого "вставляем":
        --   1) новый клиент (в current_ver нет строки);
        --   2) изменившийся клиент (статус поменялся).
        SELECT
            t.customer_bk,
            t.status,
            t.hashdiff,
            t.eff_date
        FROM delta t
        LEFT JOIN current_ver c
          ON c.customer_bk = t.customer_bk
        WHERE c.customer_status_sk IS NULL
           OR (c.hashdiff <> t.hashdiff AND t.eff_date > c.valid_from)
    )
    INSERT INTO dds.dim_customer_status (
        customer_bk, status, hashdiff,
        valid_from, valid_to,
        created_at, updated_at
    )
    SELECT
        t.customer_bk, t.status, t.hashdiff,
        t.eff_date, NULL,
        now(), now()
    FROM to_insert t
    -- защита от повторного запуска: не вставляем одну и ту же версию (BK + valid_from) второй раз
    WHERE NOT EXISTS (
        SELECT 1
        FROM dds.dim_customer_status d
        WHERE d.customer_bk = t.customer_bk
          AND d.valid_from = t.eff_date
    );
COMMIT;

-- Проверка: у клиента 101 должна появиться 5-я строка (active с 2024-11-15),
-- у 104 - первая строка (new с 2024-06-01)
SELECT 'dim_customer_status after increment = ' || COUNT(*) FROM dds.dim_customer_status;
SELECT * FROM dds.dim_customer_status ORDER BY customer_bk, valid_from;

-- ==========================================================
-- 4) DM: витрина статусов клиентов по датам (full refresh)
-- ==========================================================

-- Витрина "снимок на дату":
-- для каждого дня считаем, сколько клиентов было в каждом статусе.
-- Берём календарь dds.dim_date и подбираем статус по периоду valid_from/valid_to.
-- DDL витрины - в 07_ddl_hw_customer_status.sql.

TRUNCATE dm.mart_customer_status_daily;

WITH bounds AS (
    SELECT
        min(valid_from)                                           AS date_from,
        -- CURRENT_DATE для открытых интервалов (valid_to IS NULL = текущий статус),
        -- иначе витрина не покроет даты после последней смены статуса.
        max(coalesce(valid_to, CURRENT_DATE))                     AS date_to
    FROM dds.dim_customer_status
)
INSERT INTO dm.mart_customer_status_daily (
    date_actual, status, customers_cnt
)
SELECT
    d.date_actual,
    s.status,
    COUNT(DISTINCT s.customer_bk)                                 AS customers_cnt
FROM dds.dim_date d
JOIN bounds b
  ON d.date_actual BETWEEN b.date_from AND b.date_to
JOIN dds.dim_customer_status s
  ON d.date_actual >= s.valid_from
 AND (s.valid_to IS NULL OR d.date_actual < s.valid_to)
GROUP BY d.date_actual, s.status
ORDER BY d.date_actual, s.status;

-- Проверка: выборочные даты из витрины
SELECT 'mart_customer_status_daily count = ' || COUNT(*) FROM dm.mart_customer_status_daily;
SELECT *
FROM dm.mart_customer_status_daily
WHERE date_actual IN ('2024-01-15', '2024-04-10', '2024-09-15', '2024-12-01')
ORDER BY date_actual, status;
