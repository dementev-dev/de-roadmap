# Структура хранилища данных (для студентов SQL/Postgres)

> **Цель**: объяснить, как раскладывать данные в аналитической БД и почему именно так принято. Рус/Eng термины приводятся вместе (например, «витрина (Data Mart)»).

---

## 0. Навигация по статье

* [1. Введение: зачем слои и почему не «всё в одну таблицу»](#1)
* [2. Учебный домен/пример](#2)
* [3. Типичная структура слоёв (STG → ODS → DDS → DM)](#3)
* [4. Слои по отдельности](#4)
* [5. Модели данных для DDS/DM: 3NF, Звезда/Снежинка, Data Vault, Anchor](#5)
* [6. Ключевые понятия: факт/измерение, зерно, SK vs BK, SCD](#6)
* [7. Выбор подхода: дерево решений](#7)
* [8. Эволюция схемы и эксплуатации](#8)
* [9. MVP учебного проекта](#9)
* [10. Заключение](#10)

---

## <a id="1"></a>1. Введение: зачем слои и почему не «всё в одну таблицу»

**Коротко**: OLTP vs OLAP, управляемость, прозрачность, стоимость.

**Заглушки для текста**:

* Что такое слои и какую проблему решают.
* Почему «одна большая таблица» ломается на истории и изменениях.
* 3–4 тезиса о выгодах послойной архитектуры.

---

## <a id="2"></a>2. Учебный домен/пример (интернет-магазин)

**Описание**: используем один домен сквозь статью: клиенты, товары, заказы, позиции заказа, цены, акции.

**Диаграмма ER (эскиз)**:

```mermaid
erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ ORDER_ITEM : contains
    PRODUCT ||--o{ ORDER_ITEM : referenced
    PRODUCT ||--o{ PRICE : has
    PROMO ||--o{ ORDER_ITEM : applied
    CUSTOMER {
      int customer_id PK
      string email
      string phone
    }
    PRODUCT {
      int product_id PK
      string name
    }
    ORDER {
      int order_id PK
      date order_date
      int customer_id FK
    }
    ORDER_ITEM {
      int order_item_id PK
      int order_id FK
      int product_id FK
      int qty
      numeric price_at_sale
    }
    PRICE {
      int product_id FK
      date valid_from
      date valid_to
      numeric price
    }
    PROMO {
      int promo_id PK
      string code
    }
```

**Заглушки**: 2–3 абзаца с пояснениями domain-гранулярности и бизнес-ключей (BK).

---

## <a id="3"></a>3. Типичная структура слоёв (STG → ODS → DDS → DM)

**Картинка-конвейер (эскиз)**:

```mermaid
graph TD
  subgraph Sources[Источники]
    A[CRM] -->|ingest| STG
    B[Billing] -->|ingest| STG
    C[E-comm] -->|ingest| STG
  end
  STG[STG (Staging/Bronze)] --> ODS[ODS (Operational/Silver)]
  ODS --> DDS[DDS (Integrated/Conformed)]
  DDS --> DM[DM (Data Marts/Gold)]
  DM --> BI[BI/Отчёты/Дашборды]
  classDef layer fill:#eef,stroke:#555,stroke-width:1px;
  class STG,ODS,DDS,DM,BI layer;
```

**Заглушки**:

* Соответствие Bronze/Silver/Gold.
* Что происходит на каждом переходе в 1–2 фразы.

---

## <a id="4"></a>4. Слои по отдельности

### 4.1 STG (Staging/Bronze)

**Коротко**: «как пришло». Идемпотентность, дедупликация, неизменяемость/переигрузка.

**TODO**: список «что можно» / «что нельзя»; форматы; контроль качества на входе.

### 4.2 ODS (Operational Data Store/Silver)

**Коротко**: чистка и выравнивание типов, базовая унификация кодов, ещё без тяжёлой бизнес-логики.

**TODO**: правила именования, ключи, простая история.

### 4.3 DDS (Integrated/Conformed Layer)

**Коротко**: интеграция источников, общие справочники, SK/BK, SCD.

**TODO**: где хранить историю, антидубли, конформные измерения.

### 4.4 DM (Data Marts/Gold)

**Коротко**: модели под задачи BI (звезда/снежинка). Агрегаты, материализации.

**TODO**: границы ответственности витрин.

---

## <a id="5"></a>5. Модели данных для DDS/DM: 3NF, Звезда/Снежинка, Data Vault, Anchor

### 5.1 3NF (по Инмону, 3-я нормальная форма)

**Идея**: целостная интегрированная модель предприятия.

**Мини-эскиз (ER, нормализовано)**:

```mermaid
erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ ORDER_ITEM : contains
    PRODUCT ||--o{ ORDER_ITEM : referenced
    CATEGORY ||--o{ PRODUCT : classifies
    PRICE ||--o{ PRODUCT : defines
```

**TODO**: плюсы/минусы, когда выбирать.

### 5.2 Звезда/Снежинка (по Кимбаллу)

**Идея**: простые и быстрые аналитические запросы.

**Эскиз звезды: факт + измерения**:

```mermaid
graph LR
  F[fact_orders\n(order_id, date_key, customer_key, product_key, qty, amount)]
  D1[dim_date] --> F
  D2[dim_customer] --> F
  D3[dim_product] --> F
  D4[dim_store] --> F
```

**Эскиз снежинки (нормализация измерения продукта)**:

```mermaid
graph LR
  D3[dim_product] --> C[dim_category]
```

**TODO**: зерно факта, типы измерений, агрегаты.

### 5.3 Data Vault 2.0 (Hub–Link–Satellite)

**Идея**: масштабируемая интеграция многоисточниковых данных с полной историей.

**Эскиз DV:**

```mermaid
graph LR
  subgraph H[Hubs]
    H_C[Hub_Customer\n(BK:customer_natural_key)]
    H_P[Hub_Product\n(BK:product_code)]
    H_O[Hub_Order\n(BK:order_number)]
  end
  subgraph L[Links]
    L_OP[Link_OrderProduct\n(H_O,H_P)]
    L_OC[Link_OrderCustomer\n(H_O,H_C)]
  end
  subgraph S[Satellites]
    S_C[SAT_Customer\n(attrs, eff_from, eff_to)]
    S_P[SAT_Product\n(attrs, eff_from, eff_to)]
    S_O[SAT_Order\n(attrs, eff_from, eff_to)]
  end
  H_C --> S_C
  H_P --> S_P
  H_O --> S_O
  H_O --> L_OP
  H_P --> L_OP
  H_O --> L_OC
  H_C --> L_OC
```

**TODO**: Raw Vault vs Business Vault, плюс/минус.

### 5.4 Anchor Modeling (Анкерное моделирование)

**Идея**: эволюционируемость атрибутов с версионированием на уровне «якорей/атрибутов/узлов».

**Эскиз (упрощённый)**:

```mermaid
graph LR
  A_C[Anchor CUSTOMER]
  K_CID[Knot CUSTOMER_ID (BK)]
  A_C -- has --> K_CID
  A_C -- attr --> C_NAME[Attribute NAME]
  A_C -- attr --> C_EMAIL[Attribute EMAIL]
  C_NAME -- history --> C_NAME_VAL[Value + timeline]
  C_EMAIL -- history --> C_EMAIL_VAL[Value + timeline]
```

**TODO**: где уместно, порог входа.

---

## <a id="6"></a>6. Ключевые понятия (минимум для практики)

* **Факты (Facts)** и **Измерения (Dimensions)**; **зерно (grain)** факта.
* **Натуральные ключи (BK)** и **суррогатные ключи (SK)**.
* **SCD (Slowly Changing Dimensions)**: типы 1 / 2 / 4 / 6.
* **Bridge/Junk dimensions**, календарь, валюта, часовой пояс.
* **Поздно прибывающие события (late arriving)**.

**Эскиз SCD‑истории (Type 2) как лента времени**:

```mermaid
gantt
    dateFormat  YYYY-MM-DD
    title  SCD Type 2: dim_customer.name
    section Customer 42
    Version_1 :active, v1, 2023-01-01, 2023-06-14
    Version_2 : v2, 2023-06-15, 2024-02-28
    Version_3 : v3, 2024-03-01, 2025-10-26
```

**TODO**: короткие примеры для Type 1/2/4/6.

---

## <a id="7"></a>7. Выбор подхода: дерево решений (эскиз)

```mermaid
graph TD
  Q0{Сколько источников?} -->|1–2| Q1{Требуется глубокая история?}
  Q0 -->|3+| Q2{Схемы часто меняются?}
  Q1 -->|нет| STAR[DM: Звезда/Снежинка]
  Q1 -->|да| Q1a{Высокая BI‑нагрузка?}
  Q1a -->|да| STAR2[DM: Звезда/Снежинка]
  Q1a -->|нет| NF3[DDS: 3NF + DM при необходимости]
  Q2 -->|да| DV[ DDS: Data Vault → DM: Звезда ]
  Q2 -->|нет| MIX[ DDS: 3NF или упрощённый конформный слой → DM: Звезда ]
```

**TODO**: превратить в 6–8 вопросов с текстовыми пояснениями.

---

## <a id="8"></a>8. Эволюция схемы и эксплуатационные практики

* Совместимость назад/вперёд, view‑based миграции.
* Идемпотентные пайплайны, дедупликация, инкрементальные загрузки (CDC).
* Data Quality: уникальность, ссылочная целостность, распределения, «contracts».
* Каталог/линейка (Data Catalog / Lineage), словарь данных (Business Glossary), владение.

**TODO**: чек-лист из 8–10 пунктов.

---

## <a id="9"></a>9. MVP учебного проекта (рецепт)

1. STG: положить сырые данные из 2–3 источников.
2. ODS: очистка и выравнивание типов.
3. DDS: либо упрощённая интеграция (конформные справочники), либо Raw Vault.
4. DM: одна звезда `fact_orders` + 3–4 измерения.
5. Простой отчёт/дашборд и верификация цифр.
6. Мини‑тесты качества данных.

**Эскиз «дорожной карты»**:

```mermaid
graph LR
  S[STG готов] --> O[ODS готов] --> D[DDS готов] --> M[DM готов] --> R[Отчёт готов]
```

---

## <a id="10"></a>10. Заключение

**Заглушки**: повторить ключевые тезисы, дать ссылки на дополнительные темы: CDC, оркестрация, тестирование данных, наблюдаемость.

---

## Примечания к иллюстрациям

* Диаграммы — **эскизы**: заменить/уточнить, когда будет готов текст.
* При необходимости добавить отдельные рисунки: «что можно/нельзя в слоях», SCD типы на одном полотне, пример late arriving events.
