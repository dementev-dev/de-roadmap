# О роадмапе

Этот роадмап — конспект моих подходов к обучению Data Engineering.  
Он подойдёт тем, кто хочет:
- системно войти в профессию с нуля или близкого к нулю уровня;
- закрыть пробелы в базе (SQL, Git, Python, DWH, Airflow, GreenPlum);
- подготовиться к собеседованиям и первым рабочим задачам.

Роадмап можно проходить самостоятельно или вместе со мной в формате менторства.  
Если хотите идти с поддержкой ментора — напишите в Telegram: [@dementev_dev](https://t.me/dementev_dev).

## Оглавление

- [Основные знания](#основные-знания)
- [Практика и инструменты](#практика-и-инструменты)
- [Карьера и менторство](#карьера-и-менторство)
- [Расширенные навыки](#расширенные-навыки)
- [Софт скиллы](#софт-скиллы)
- [Дополнительные материалы](#дополнительные-материалы)

Рекомендуемый способ использования:
- двигаться по разделам последовательно, не перепрыгивая через базу;
- выполнять практику и домашки, а не только смотреть материалы;
- возвращаться к разделам по мере появления реальных задач.

# Основные знания

## Git и базовые инструменты

### База по Git
Что такое контроль версий, когда используется, ПОЧЕМУ и как мы в обучении будем использовать.
Как создать репозиторий на GitHub, сохранять в нем изменения.
- [Что такое Git для Начинающих / GitHub за 30 минут / Git Уроки - Youtube](https://www.youtube.com/watch?v=VJm_AjiTEEc)
- Книга [Pro Git](https://git-scm.com/book/ru/v2) - читать главу 1

### Основы Markdown
- [Язык Markdown и файл README | Git и GitHub для начинающих - Youtube](https://www.youtube.com/watch?v=8lEDTrr-G4U)
- [Markdown и его возможности: простой способ оформления текста](https://kurshub.ru/journal/blog/markdown-chto-eto/)
- [Синтаксис Markdown: подробная шпаргалка для веб-разработчиков / Skillbox Media](https://skillbox.ru/media/code/yazyk-razmetki-markdown-shpargalka-po-sintaksisu-s-primerami/)

Домашки по остальным темам тренируемся делать в Git, там же пишем документацию.

## SQL
### База по SQL
Книга: [PostgreSQL. Основы языка SQL](https://postgrespro.ru/education/books/sqlprimer) - Глава 1 "Введение в базы данных и SQL" + ДЗ

Бесплатный тренажер: [Интерактивный тренажер по SQL – Stepik](https://stepik.org/course/63054/promo)  
Целевой уровень знания SQL - Live кодинг на собесе. Проверяем на первом мок-интервью  
**СТЕ**
 - Зачем нам CTE: [Getting started with CTEs | dbt Labs](https://www.getdbt.com/blog/getting-started-with-cte)
 - Подробнее про синтаксис: [PostgreSQL : Документация: 17: 7.8. Запросы WITH (Общие табличные выражения) : Компания Postgres Professional](https://postgrespro.ru/docs/postgresql/17/queries-with)

Для дальнейшей тренировки и поддержания уровня можно использовать [Database - LeetCode](https://leetcode.com/problem-list/database/). Хорошая подборка задачек: [SQL 50 - Study Plan - LeetCode](https://leetcode.com/studyplan/top-sql-50/)

### Повышение знаний SQL

Смотрим курс от Postgres Pro [DEV1](https://postgrespro.ru/education/courses/DEV1)
Темы - от "Введение" до "SQL" включительно, "Управление доступом", "Резервное копирование". Для лучшего усваивания материала проделываем все примеры и домашние задания из конспектов лекция.   
С темой "PL/pgSQL" можно ознакомиться обзорно.

Для развития навыков инженера будет полезно лабораторные работы делать не в виртуальной машине, а в docker контейнере. Предложенный (не обязательный) вариант - в каталоге `postgres-bookings` репозитория.

Для дальнейшего закрепления материала - читаем книгу [PostgreSQL. Основы языка SQL](https://postgrespro.ru/education/books/sqlprimer)
- Глава 8 - Индексы + ДЗ
- Глава 9 - Транзакции
- Глава 10 - Повышение производительности + ДЗ

Вопросы оптимизации запросов хорошо описаны в курсе [QPT](https://postgrespro.ru/education/courses/QPT) от Postgres Pro. Полученные навыки применимы для работы в том числе с GreenPlum, и частично, другими БД.
На момент написания, видеолекции были доступны только для старой версии Postgres 13, но ее вполне достаточно.

### Моделирование данных
Понимание того, **как устроены данные и зачем они нужны**, — ключ к качественным ETL-процессам.  
Мы кратко разбираем:
- Основные подходы: нормализованные (3NF) vs денормализованные (звезда, снежинка)
- Что такое staging, marts, слои raw / clean / business
- Как проектировать таблицы под конкретные сценарии использования

Цель — не стать архитектором, а **уметь читать и объяснять структуру данных**, чтобы писать осмысленные запросы и трансформации.

Материалы:
- [Яндекс Практикум: что такое нормализация, простыми словами (для самых начинающих)](https://practicum.yandex.ru/blog/chto-takoe-normalizaciya-dannyh/)
- [Базы данных. 1,2,3 нормальные формы. - Youtube](https://www.youtube.com/watch?v=zwQzL80U51c)
- [Введение в структуру хранилища данных](dwh-modeling/README.md)
- Теория про Slowly Changing Dimensions: [SCD](dwh-modeling/SCD.md)
- Еще про Data Vault:
  - [Введение в Data Vault - Хабр](https://habr.com/ru/articles/348188/)
  - [Основы Data Vault - Хабр](https://habr.com/ru/articles/502968/)
  - [DataVault за 10 минут - Youtube](https://www.youtube.com/watch?v=9oQs_wJ045I)
  - Статья [«Что такое Data Vault: моделирование КХД для архитектора Big Data»](https://bigdataschool.ru/blog/what-is-data-vault/) — обзор, плюсы/минусы, контекст применения.
  - [Гибкие методологии проектирования Data Vault и Anchor Modeling | Евгений Ермаков | karpov.courses](https://www.youtube.com/watch?v=fNGIOb8SJvU)
  - Лекция в рамках курса по DWH: именно [«Основы Data Vault, создаем первую модель»](https://www.youtube.com/watch?v=65b99XCuiR4) — хороший формат: теория + пример.
  - Доклад - практический пример: [Денис Лукьянов — Data Vault 2.0. Когда внедрять, проблемы применения при построении DWH на Greenplum](https://www.youtube.com/watch?v=oGwQbeP5iss)
- Краткая теория про [DWH](https://halltape.github.io/HalltapeRoadmapDE/DWH/) - повторим еще раз, в другом изложении
- Хорошее общее введение в модели данных дано в статье и докладе от Yandex: [Как мы внедрили свою модель хранения данных — highly Normalized hybrid Model. Доклад Яндекса](https://habr.com/ru/companies/yandex/articles/557140/)

**Когда блок SQL считаем пройденным:**
- вы уверенно пишете запросы с JOIN, агрегатами, подзапросами и CTE;
- можете объяснить простую модель данных (3NF/звезда) и прочитать схему DWH;
- решаете типовые задачи уровня SQL live-coding без долгих пауз.


## Python

- Если совсем не знакомы с Python, начинаем с курса ["Поколение Python": курс для начинающих – Stepik](https://stepik.org/course/58852/info)
- Изучаем глубже и "оттачиваем" live coding: ["Поколение Python": курс для продвинутых – Stepik](https://stepik.org/course/68343/info)
- Продолжение "базы", спрашиваемой на собеседованиях, по Python: ["Поколение Python": курс для профессионалов](https://stepik.org/course/82541/promo). Курс очень полезный, но платный.
- "Продвинутые" темы:
  - [Полезные функции](https://pyneng.readthedocs.io/ru/latest/book/10_useful_functions/index.html)
  - [Работа с файлами в формате CSV, JSON, YAML](https://pyneng.readthedocs.io/ru/latest/book/17_serialization/index.html)
  - [Итераторы, итерируемые объекты и генераторы](https://pyneng.readthedocs.io/ru/latest/book/13_iterator_generator/index.html)
  - [Декораторы Python: пошаговое руководство](https://habr.com/ru/companies/otus/articles/727590/)
  - Работа с датой/временем: https://django.fun/docs/python/3.10/library/datetime/
- ООП
  - [Tproger: «ООП простыми словами»](https://tproger.ru/experts/oop-in-simple-words)
  - Введение в [ООП](https://metanit.com/python/tutorial/7.1.php)
  - [Яндекс Учебник: «Объектная модель Python: классы, поля и методы»](https://education.yandex.ru/handbook/python/article/obuektnaya-model-python-klassy-polya-i-metody)
  - [Real Python: OOP in Python (tutorial)](https://realpython.com/python3-object-oriented]
- Jupyter Lab
  - [Блог Практикума: «Что такое Jupyter Notebook: как установить и открыть»](https://practicum.yandex.ru/blog/chto-takoe-jupyter-notebook/)
  - Готовая реализация Jupyter Lab, включающая в себя Spark, в Docker: https://github.com/dementev-dev/jupyter-spark-docker
- Pandas
  - [GeeksforGeeks: “Why Pandas is Used in Python”](https://www.geeksforgeeks.org/pandas/why-pandas-is-used-in-python/)
  - [Skillbox: «Для чего нужна библиотека Pandas»](https://skillbox.ru/media/code/rabotaem-s-pandas-osnovnye-ponyatiya-i-realnye-dannye/)
  - [Official: “10 minutes to pandas”](https://pandas.pydata.org/docs/user_guide/10min.html)
  - [Хабр (RUVDS): «Моя шпаргалка по pandas»](https://habr.com/ru/companies/ruvds/articles/494720/)
  - [Tproger: «Наглядная шпаргалка по операциям с DataFrame»](https://tproger.ru/articles/pandas-data-wrangling-cheatsheet)


Полезно, но дороговато и не обязательно: хорошее комбо SQL + Python — ["Поколение Python": профи + ООП + SQL – Stepik](https://stepik.org/course/233341/promo?search=7181036958)

Цель — уверенно решать простые задачи на Python в формате live-coding; дальше эти навыки пригодятся для создания DAG Airflow.

**Когда блок Python считаем пройденным:**
- вы без подсказок пишете небольшие скрипты с циклами, функциями, обработкой ошибок и работой с коллекциями;
- умеете читать и модифицировать чужой код, в том числе с использованием pandas и DataFrame;
- уверенно проходите простой live-coding по Python для DE: прочитать CSV/JSON, отфильтровать, сгруппировать данные и посчитать агрегаты.
- можете отвечать как на простые вопросы собеседований (циклы, списки, словари), так и продвинутые (итераторы, декораторы, управление памятью, базовые понятия ООП)

## Технические навыки

### Продвинутый Git
- Сжатый, но емкий видеогайд: [GIT, GitHub, GitLab. Полный АКТУАЛЬНЫЙ гайд ЗА ПОЛТОРА ЧАСА. Без этого выгонят с работы - Youtube](https://www.youtube.com/watch?v=0Y-fneoUIO8)
- Книга: [Pro Git](https://git-scm.com/book/ru/v2) - главы 
    - 2 Основы Git
    - 3 Ветвление в Git
    - 5 Распределённый Git
    - 6 GitHub
- [Курс работы с Git и GitLab - ЭФКО ЦПР | YouTube плейлист](https://www.youtube.com/playlist?list=PLbf8m52BvqlFlblJqQKPuEU26pwgqe7zK)

Целевой уровень знания - понимание процесса GitFlow. Как создать ветку, влить изменения в другие ветки. Понимание, зачем.
На собесах обычно не спрашивают, но нужно в работе.

### Docker
- Курс https://karpov.courses/docker

Основное предназначение для нас - учебные стенды, где мы разбираем и тренируемся с разными технологиями. На работе - иногда пригождается. На собесах спрашивают редко.

### Методы разработки

Кратко знакомимся с основными подходами к организации работы в IT: 

- **Водопад** — последовательная разработка,
- **Scrum / Kanban** — гибкие методологии, популярные в data-командах.

Понимание этих концепций помогает быстрее адаптироваться в новых проектах и правильно интерпретировать требования.

### Запись встреч
OBS Studio
[Настройка записи экрана](https://docs.google.com/document/d/1qd8uRYlAaZp9c5zpvCVBOvYQCEukGHI9PEPjnjahI1k/)

# Практика и инструменты

## Airflow
Apache Airflow — инструмент для оркестрации ETL-процессов.

Мы используем его для: 
- планирования задач,
- отслеживания зависимостей между шагами,
- визуализации статуса выполнения.

Материалы:
- [Учебник по Airflow](https://github.com/dementev-dev/airflow-manual)

**Когда блок Airflow считаем пройденным:**
- вы можете объяснить, что такое DAG, задачи, операторы и сенсоры, и как между ними задаются зависимости;
- на базе учебного стенда подготавливаете, отлаживаете и запускаете свои DAG'и с расписанием и несколькими шагами (например, загрузка данных и последующие трансформации);
- уверенно смотрите логи, находите место падения и понимаете, как перезапустить задачу.

## Greenplum
Разбираем, чем Greenplum отличается от PostgreSQL и зачем нужны MPP-хранилища.

Предварительно:
- Простое введение: [Greenplum | Что это такое и как оно работает? - Youtube](https://www.youtube.com/watch?v=rLG9Z_HcKPY)
- Оно же, но текстом: https://halltape.github.io/HalltapeRoadmapDE/GREENPLUM/
- [Визуализатор распределения Greenplum](https://gpskew.rzvde.pro/)
- Бесплатный, но большой учебный курс от Yandex: https://yandex.cloud/ru/training/greenplum
- [Учебный курс по Greenplum от datafiner](https://datafinder.ru/products/uchebnyy-kurs-po-greenplum) — взять только отдельные главы.

Практика (минимум, который мы делаем вместе, чтобы уверенно чувствовать себя на собеседованиях): 
- [DE Starter Kit — Airflow + Greenplum + CSV](https://github.com/dementev-dev/airflow-greenplum)

Сложные варианты с виртуалками — только если менти сильно захочет, в базовый путь не включаем.

**Когда блок Greenplum считаем пройденным:**
- вы понимаете, как данные распределяются по сегментам, что такое skew и как его увидеть;
- на базе учебного стенда (например, DE Starter Kit) можете загружать и выгружать данные в Greenplum, выполнять запросы и разбирать планы выполнения (`EXPLAIN`);
- можете объяснить, в чём практическая разница между MPP-хранилищем и одиночным Postgres на уровне типичных задач DE и собеседований.

## Курсовая работа
### Стенд в Docker Compose 
- Apache Airflow
    - Источник данных - TelecomX
- GreenPlum
- ETL
- Исходные коды всего - в Git

## Понятие сложности алгоритмов
В Data Engineering редко требуется писать сложные алгоритмы, но важно понимать, как оценивать эффективность кода: 

- в SQL — через объём сканируемых данных, типы JOIN’ов, использование индексов;
- в Python — через асимптотику операций с pandas/списками (например, O(n) vs O(n²)).

Это помогает избегать «тормозящих» решений на собеседованиях и в реальных пайплайнах.

# Карьера и менторство

## Менторство по этому роадмапу

Если вы нашли этот роадмап в интернете и хотите пройти его не в одиночку, а с поддержкой ментора, можно присоединиться ко мне.

**Что даёт менторство:**
- структурный план прохождения роадмапа под вашу ситуацию;
- разбор вопросов по SQL / DWH / Airflow и другим темам из этого документа;
- разбор домашних заданий и код-ревью;
- помощь с подготовкой к собеседованиям (резюме, мок-интервью).

**Как записаться**

Просто напишите мне в Telegram: [@dementev_dev](https://t.me/dementev_dev)  
со словами «Хочу пройти роадмап с ментором» — дальше всё обсудим.

## Подготовка к собеседованиям
Цель блока — сформировать «опыт от 2 лет» и уметь корректно его показать в резюме и на собеседовании.

### Помощь в подготовке резюме

- Видео от ОМ по составлению резюме
    - [Как накрутить опыт в резюме | «Ультимативный гайд» ‪@digital_ninja‬](https://www.youtube.com/watch?v=EPuogJuYsvY)
    -  [Как писать резюме, чтобы его читали - доклад - Boosty](https://boosty.to/m0rtymerr/posts/71b02a6b-8116-466a-b945-b2ed793abd8f)
    - [Как грамотно продать себя на собеседовании / Созвон сообщества - Boosty](https://boosty.to/m0rtymerr/posts/7289cd23-60c6-4010-bb1c-a5b28dac399a)
- Попытки менти написать, моя обратная связь - итеративно

### Навыки поиска работы с HH и Habr карьера

- [Как накрутить опыт в резюме | «Ультимативный гайд» ‪@digital_ninja‬](https://www.youtube.com/watch?v=EPuogJuYsvY)
- [Как подтвердить опыт без трудовой / Хабр против работяг](https://www.youtube.com/watch?v=GHqABzA1zi8)
- [Как успешно пройти испытательный срок в IT | «Ультимативный гайд» c @digital_ninja - Youtube](https://www.youtube.com/watch?v=r1lWP5rYVdk)
- Видео по прохождению собесов от ОМ.
- Мои комментарии к нему, мой опыт
- Первые тренировки мок собесы, обратная связь

### Помощь с прохождением испытательного срока

- [Как успешно пройти испытательный срок в IT | «Ультимативный гайд» c @digital_ninja - Youtube](https://www.youtube.com/watch?v=r1lWP5rYVdk)
- [Испытательный срок - доклад - Boosty](https://boosty.to/m0rtymerr/posts/40e7f17e-022b-495c-8d03-dabbe4383b8e)



# Расширенные навыки
Эти темы выходят за рамки базового минимума для старта в Data Engineering, но дают более полное представление об экосистеме.  
Их цель — понимать, зачем и когда используется тот или иной инструмент, а не осваивать его на уровне администратора или DevOps-инженера.

Мы кратко знакомимся с:

- **Apache NiFi** и **Kafka** — инструментами для построения потоковых и интеграционных пайплайнов;
- **ClickHouse** — колоночной СУБД для высоконагруженной аналитики;
- **dbt** — подходом к трансформации данных как кода.

Практика ограничивается минимальным рабочим примером (например, запуск в Docker, простой пайплайн или SQL-модель).

Этого достаточно, чтобы уверенно говорить об инструменте на собеседовании и понимать его место в архитектуре — а всё остальное при необходимости осваивается уже на проекте.

## ClickHouse
Бесплатный курс https://yandex.cloud/ru/training/clickhouse  
Платный курс [ClickHouse для аналитика – Stepik](https://stepik.org/course/100210/promo?search=6551441002)  

## NiFi
Плейлист [Apache NiFi с нуля за 3 часа. Конструктор вместо кода - Youtube](https://youtube.com/playlist?list=PL4MpKy3QjNp_rOEEibc4Ro8UK4g8vLX6_&si=W_hidjHmBOZ_aUfS) — первые 4 видео, дальше — по желанию.

Практика (делаем вместе):
- собираем отдельный стенд в Docker Compose с Postgres и NiFi;
- в NiFi настраиваем простой генератор данных.

## Kafka
[Лучший Гайд по Kafka для Начинающих За 1 Час - Youtube](https://www.youtube.com/watch?v=hbseyn-CfXY)

Практика:
Практика (делаем вместе):
- расширяем предыдущий стенд, добавляя Kafka;
- строим поток данных: NiFi → Kafka;
- добавляем обратный поток: Kafka → NiFi → Postgres.

## dbt
dbt (data build tool) — инструмент для трансформации данных в хранилище.

Мы рассматриваем его как альтернативу «ручному» написанию сложных CTE и для понимания современного подхода к моделированию данных как кода.

# Софт скиллы
- [Все ветви дохода в IT / Полный гайд по деньгам](https://youtube.com/live/JHClTWwK1EM)
- [Гайд как писать отзывы](https://boosty.to/m0rtymerr/posts/b04040ec-0f46-4524-9c75-188a513140ad?share=post_link)  
- [Гайд по Антистрессу](https://youtu.be/bu0YiXOKaoU)

# Дополнительные материалы
- [ananevsyu/SandBox_DB_public: Песочница для изучения различных технологий связанных с инженерией данных](https://gitflic.ru/project/ananevsyu/sandbox_db_public)
    - Клон проекта [dementev_dev/sandbox_db_public-форк](https://gitflic.ru/project/dementev_dev/sandbox_db_public-fork)
- [Индексы в БД - Youtube](https://www.youtube.com/watch?v=DyqtBiDrz3g)
- [Spark + Iceberg in 1 Hour - Memory Tuning, Joins, Partition - Youtube](https://www.youtube.com/watch?v=3R-SLYK-P_0)
- [Введение в устройство Parquet и Iceberg - habr](https://habr.com/ru/companies/vktech/articles/959398/)
- [Введение в Apache Iceberg. Основы, архитектура, как работает?](https://ivan-shamaev.ru/apache-iceberg-tutorial-architecture-how-to-work/#__Apache_Iceberg-2)
- [Алгоритмы: теория и практика. Методы – Stepik](https://stepik.org/course/217/info)
- [Алгоритмы: теория и практика. Структуры данных – Stepik](https://stepik.org/course/1547/promo)
- [Apache Hadoop для самых маленьких: HDFS, RACK-AWARENESS, репликация и Data Locality - Youtube](https://youtu.be/0fsY5bW2l84)
- [Книга. Введение в Apache Kafka для системных аналитиков и проектировщиков интеграций](https://systems.education/kafka)
- [Перевод документации dbt на русский язык](https://docs.getdbt.tech/)

## Записи ОМ
- [Как пройти собеседование на программиста | Ультимативный гайд с ‪@om_nazarov‬ - Youtube](https://www.youtube.com/watch?v=tzSdiYZ52kI)
- [Как стать программистом в 2025 | «Ультимативный гайд» с ‪@om_nazarov‬](https://www.youtube.com/watch?v=6151ekTOl38)
