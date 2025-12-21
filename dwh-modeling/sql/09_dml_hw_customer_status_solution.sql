-- ===============================================
-- 09_dml_hw_customer_status_solution.sql
-- Решение домашки: статусы клиента (STG -> ODS -> DDS SCD2 -> DM)
--
-- Что делает этот файл:
--   1) Перекладывает события статусов в ODS (приводит типы, чистит пустое).
--   2) Строит DDS-измерение со "встроенной историей" (SCD2): периоды valid_from/valid_to.
--   3) Показывает пример обновления DDS маленькой порцией (инкремент): закрыть старое + вставить новое.
--   4) Собирает простую витрину в DM: сколько клиентов в каком статусе по дням.
--
-- Как запускать:
--   - для первого знакомства можно запускать файл целиком;
--   - если хотите потренировать инкремент (п.3): добавьте новые события -> обновите ODS -> запустите блок 3 ещё раз.
--
-- Важно:
--   - здесь часто используется TRUNCATE (полная очистка), чтобы было легко повторять домашку;
--   - в реальном DWH так делают не всегда, но для обучения это удобнее.
--
-- Предусловия (DDL + данные в STG):
--   1) dwh-modeling/sql/01_ddl_stg-dds.sql
--   2) dwh-modeling/sql/05_ddl_dm.sql
--   3) dwh-modeling/sql/07_ddl_hw_customer_status.sql
--   4) stg.customer_status_raw заполнена (см. dwh-modeling/Homework_Customer_Status_DDS_DM.md)
-- ===============================================

-- ==========================================================
-- 1) ODS: очистка и типизация (full refresh)
-- ==========================================================

-- Идея:
--   - STG хранит "как пришло" (обычно TEXT);
--   - ODS хранит "аккуратно": правильные типы + простая чистка.
-- Для простоты пересобираем ODS с нуля.

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

-- ==========================================================
-- 3) DDS: инкрементальная загрузка SCD2 (по последним событиям)
-- ==========================================================

-- Этот блок нужен, чтобы показать "как это обычно обновляют":
-- после новой порции событий мы:
--   1) берём по каждому клиенту самое позднее событие из ODS;
--   2) сравниваем его с текущей версией в DDS (valid_to IS NULL);
--   3) если статус изменился — закрываем старую версию и вставляем новую.
--
-- Ограничение учебного варианта (в домашке можно игнорировать):
--   - если вы добавили событие "задним числом" со старой датой, этот блок не пересоберёт всю историю.
--     Для такого кейса обычно делают отдельную логику или full refresh.
--
-- Примечание:
--   - в этом файле блок 2 (full refresh) запускается раньше, поэтому сразу после него
--     блок 3, скорее всего, ничего не изменит. Зато его можно повторять после новых событий.

BEGIN;
    -- 3.1) Закрываем предыдущую актуальную версию
    WITH ranked AS (
        -- ranked: выбираем "самое свежее" событие на клиента.
        -- Если event_ts одинаковый, берём то, что загрузилось позже (_load_ts).
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
    current AS (
        -- current: текущие версии в DDS (valid_to IS NULL)
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
        JOIN current c
          ON c.customer_bk = t.customer_bk
        WHERE c.hashdiff <> t.hashdiff
          AND t.eff_date > c.valid_from  -- не создаём период нулевой/отрицательной длины
      ) x
     WHERE d.customer_status_sk = x.customer_status_sk
       AND d.valid_to IS NULL;

    -- 3.2) Вставляем новую версию
    WITH ranked AS (
        -- ranked/delta/current повторяем отдельно, чтобы блок INSERT читался отдельно от UPDATE
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
    current AS (
        SELECT d.*
        FROM dds.dim_customer_status d
        WHERE d.valid_to IS NULL
    ),
    to_insert AS (
        -- to_insert: кого "вставляем":
        --   1) новый клиент (в current нет строки);
        --   2) изменившийся клиент (статус поменялся).
        SELECT
            t.customer_bk,
            t.status,
            t.hashdiff,
            t.eff_date
        FROM delta t
        LEFT JOIN current c
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

-- ==========================================================
-- 4) DM: витрина статусов клиентов по датам (full refresh)
-- ==========================================================

-- Витрина "снимок на дату":
-- для каждого дня считаем, сколько клиентов было в каждом статусе.
-- Берём календарь dds.dim_date и подбираем статус по периоду valid_from/valid_to.

CREATE TABLE IF NOT EXISTS dm.mart_customer_status_daily (
    date_actual    DATE        NOT NULL,
    status         VARCHAR(20) NOT NULL,
    customers_cnt  INT         NOT NULL
);

TRUNCATE dm.mart_customer_status_daily;

WITH bounds AS (
    SELECT
        min(valid_from)                                           AS date_from,
        max(coalesce(valid_to, valid_from))                       AS date_to
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
