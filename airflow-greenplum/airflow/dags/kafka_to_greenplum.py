from __future__ import annotations
import os, json, random
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
import psycopg2
from confluent_kafka import Producer, Consumer, KafkaException

# Greenplum (Postgres wire protocol)
GP_DSN = {
    "dbname": os.getenv("GP_DB", "gpadmin"),
    "user": os.getenv("GP_USER", "gpadmin"),
    "password": os.getenv("GP_PASSWORD", ""),
    "host": os.getenv("GP_HOST", "greenplum"),
    "port": int(os.getenv("GP_PORT", "5432")),
}

KAFKA_BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "kafka:9092")
TOPIC = os.getenv("KAFKA_TOPIC", "orders")

def _create_table():
    ddl = """
    CREATE TABLE IF NOT EXISTS public.orders (
        order_id BIGINT PRIMARY KEY,
        order_ts TIMESTAMP NOT NULL,
        customer_id BIGINT NOT NULL,
        amount NUMERIC(12,2) NOT NULL
    )
    WITH (appendonly=true, orientation=column, compresstype=zlib)
    DISTRIBUTED BY (order_id);
    """
    with psycopg2.connect(**GP_DSN) as conn, conn.cursor() as cur:
        cur.execute(ddl)
        conn.commit()

def _produce(n=1000):
    p = Producer({"bootstrap.servers": KAFKA_BOOTSTRAP})
    for i in range(n):
        payload = {
            "order_id": i + 1,
            "order_ts": datetime.utcnow().isoformat(),
            "customer_id": random.randint(1, 100),
            "amount": round(random.uniform(10, 500), 2),
        }
        p.produce(TOPIC, json.dumps(payload).encode("utf-8"))
    p.flush()

def _consume_and_load(max_messages=1000, timeout_s=10):
    consumer = Consumer({
        "bootstrap.servers": KAFKA_BOOTSTRAP,
        "group.id": "airflow-loader-gp",
        "auto.offset.reset": "earliest",
        "enable.auto.commit": False,
    })
    consumer.subscribe([TOPIC])

    with psycopg2.connect(**GP_DSN) as conn, conn.cursor() as cur:
        inserted = 0
        while inserted < max_messages:
            msg = consumer.poll(timeout_s)
            if msg is None:
                break
            if msg.error():
                raise KafkaException(msg.error())
            d = json.loads(msg.value().decode("utf-8"))
            # GPDB6 не поддерживает ON CONFLICT — используем WHERE NOT EXISTS
            cur.execute(
                """
                INSERT INTO public.orders(order_id, order_ts, customer_id, amount)
                SELECT %s, %s, %s, %s
                WHERE NOT EXISTS (
                    SELECT 1 FROM public.orders WHERE order_id = %s
                );
                """,
                (d["order_id"], d["order_ts"], d["customer_id"], d["amount"], d["order_id"]),
            )
            inserted += 1
        conn.commit()

    consumer.commit(); consumer.close()

default_args = {"owner": "airflow", "retries": 1, "retry_delay": timedelta(seconds=30)}

with DAG(
    dag_id="kafka_to_greenplum",
    start_date=datetime(2024, 1, 1),
    schedule_interval=None,
    catchup=False,
    default_args=default_args,
    tags=["demo", "kafka", "greenplum"],
) as dag:

    create_table = PythonOperator(task_id="create_table", python_callable=_create_table)
    produce = PythonOperator(task_id="produce_messages", python_callable=_produce, op_kwargs={"n": 1000})
    consume_and_load = PythonOperator(task_id="consume_and_load", python_callable=_consume_and_load, op_kwargs={"max_messages": 1000})

    create_table >> produce >> consume_and_load
