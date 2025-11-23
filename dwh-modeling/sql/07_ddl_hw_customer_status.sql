-- ===============================================
-- DDL: дополнительные таблицы для домашки
-- Тема: статусы клиента (SCD2 поверх статуса)
-- Скрипт можно запускать после 01_ddl_stg-dds.sql
-- ===============================================

-- 1. STG: сырые события о статусе клиента из CRM
DROP TABLE IF EXISTS stg.customer_status_raw;
CREATE TABLE stg.customer_status_raw (
    customer_id TEXT,
    status      TEXT,
    event_ts    TEXT,
    _load_id    TEXT,
    _load_ts    TIMESTAMP DEFAULT NOW()
);

-- 2. ODS: очищенные и типизированные статусы
DROP TABLE IF EXISTS ods.customer_status;
CREATE TABLE ods.customer_status (
    customer_id INT          NOT NULL,
    status      VARCHAR(20)  NOT NULL,
    event_ts    TIMESTAMP    NOT NULL,
    _load_id    TEXT         NOT NULL,
    _load_ts    TIMESTAMP    NOT NULL
);

ALTER TABLE ods.customer_status
    ADD PRIMARY KEY (customer_id, event_ts);

-- 3. DDS: измерение статусов клиента с историей (SCD Type 2)
DROP TABLE IF EXISTS dds.dim_customer_status;
CREATE TABLE dds.dim_customer_status (
    customer_status_sk BIGSERIAL   PRIMARY KEY,
    customer_bk        INT         NOT NULL,
    status             VARCHAR(20) NOT NULL,
    hashdiff           TEXT        NOT NULL,
    valid_from         TIMESTAMP   NOT NULL,
    valid_to           TIMESTAMP   NOT NULL,
    is_current         BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMP   NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMP   NOT NULL DEFAULT NOW()
);

