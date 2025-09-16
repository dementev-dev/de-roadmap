-- Greenplum DDL (GPDB 6 совместимо)
-- Колонночная таблица (append-optimized) и распределение по ключу
CREATE TABLE IF NOT EXISTS public.orders (
    order_id    BIGINT PRIMARY KEY,
    order_ts    TIMESTAMP NOT NULL,
    customer_id BIGINT NOT NULL,
    amount      NUMERIC(12,2) NOT NULL
)
WITH (appendonly=true, orientation=column, compresstype=zlib)
DISTRIBUTED BY (order_id);
