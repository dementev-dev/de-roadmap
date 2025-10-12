-- Greenplum DDL (GPDB 6 совместимо)
-- Колонночная таблица (append-optimized) и распределение по ключу.
-- Внимание: append-optimized таблицы не поддерживают UNIQUE/PRIMARY KEY,
-- поэтому контроль дублей выполняем в DAG при загрузке.
CREATE TABLE IF NOT EXISTS public.orders (
    order_id    BIGINT,
    order_ts    TIMESTAMP NOT NULL,
    customer_id BIGINT NOT NULL,
    amount      NUMERIC(12,2) NOT NULL
)
WITH (appendonly=true, orientation=row, compresstype=zlib, compresslevel=1)
DISTRIBUTED BY (order_id);
