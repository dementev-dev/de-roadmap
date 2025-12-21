# TODO: dwh-modeling

## SCD2 (dim_customer / dim_customer_status)

- Добавить в `02_dml_stg-dds.sql` (блок SCD2 backfill) и `03_demo_increment.sql` (incremental) явные допущения:
  - гранулярность `DATE` (daily-grain), интервалы `[valid_from, valid_to)`, current = `valid_to IS NULL`;
  - предполагаем **не более одного изменения в день** на BK (иначе нужен `TIMESTAMP`/sequence);
  - `valid_from` берём как **effective date**: `COALESCE(event_ts, _load_ts)::date` (и почему так);
  - late-arriving/backdated события в демо **не обрабатываются** (что будет “в проде”).
- Коротко документировать “effective time vs load time”:
  - `event_ts` = когда изменение произошло в источнике;
  - `_load_ts` = когда событие попало в DWH;
  - `valid_from/valid_to` строим по effective time, а `_load_id/_load_ts` используем для трассировки/аудита.
- (Опционально) Добавить микросекцию “как читать CTE” в SCD2-блоках: что делает `src → ordered → changes → framed`.

## Вариант с TIMESTAMP (advanced, под вопросом)

- Подумать над отдельным примером SCD2 с `valid_from_ts/valid_to_ts TIMESTAMP`:
  - кейс “несколько изменений в один день”;
  - корректная обработка одинаковых `event_ts` (tie-breaker: `_load_ts`/`_load_id`);
  - влияние на join фактов (условие по `[from,to)`).
- Зафиксировать: показываем как “опционально/advanced”, чтобы не пугать на базовом треке.

## Greenplum (после Postgres-трека)

- Отдельно проговорить практику для больших объёмов:
  - обновления SCD2 в GP могут быть дорогими; обсудить паттерны (partitioning/append-only/минимизация UPDATE);
  - какие поля выбирать для распределения и сортировки таблиц измерений/фактов (на уровне рекомендаций).
