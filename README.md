# План обучения - Data Engineering с нуля до middle

# Основные знания

## База по Git
Что такое контроль версий, когда используется, ПОЧЕМУ и как мы в обучении будем использовать.
Как создать репозиторий на GitHub, сохранять в нем изменения.
- [Что такое Git для Начинающих / GitHub за 30 минут / Git Уроки - Youtube](https://www.youtube.com/watch?v=VJm_AjiTEEc)
- Книга [Pro Git](https://git-scm.com/book/ru/v2) - читать главу 1

### Основы Markdown
- [Язык Markdown и файл README | Git и GitHub для начинающих - Youtube](https://www.youtube.com/watch?v=8lEDTrr-G4U)
- [Markdown и его возможности: простой способ оформления текста](https://kurshub.ru/journal/blog/markdown-chto-eto/)
- [Синтаксис Markdown: подробная шпаргалка для веб-разработчиков / Skillbox Media](https://skillbox.ru/media/code/yazyk-razmetki-markdown-shpargalka-po-sintaksisu-s-primerami/)

## SQL
### База по SQL
Книга: [PostgreSQL. Основы языка SQL](https://postgrespro.ru/education/books/sqlprimer) - Глава 1 "Введение в базы данных и SQL" + ДЗ в конце главы

Бесплатный тренажер: [Интерактивный тренажер по SQL – Stepik](https://stepik.org/course/63054/promo)
Целевой уровень знания SQL - Live кодинг на собесе. Проверяем на первом мок-интервью
В помощь: [SQL 50 - Study Plan - LeetCode](https://leetcode.com/studyplan/top-sql-50/)
### Повышение знаний SQL
Выполнение домашек в виртуалке от PostgresPro DBA 1- первый виртуальный стенд [dba1_student_guide.pdf](https://edu.postgrespro.ru/16/dba1-16/dba1_student_guide.pdf)
Лекция [DBA1-16. 02. Использование psql](https://rutube.ru/video/12e30744d4e2e532a544da79d6c1ec69/?playlist=913726) +  [текстовые материалы лекции](https://edu.postgrespro.ru/16/dba1-16/dba1_02_tools_psql.html)

- Книга: [PostgreSQL. Основы языка SQL](https://postgrespro.ru/education/books/sqlprimer)
    - Глава 8 - Индексы + ДЗ
    - Глава 9 - Транзакции
    - Глава 10 - Повышение производительности + ДЗ
### Углубление знаний SQL как языка программирования
- [DEV1-12. 08. Функции](https://rutube.ru/video/21b867b6857583aa9429400dfc4bdf25/) + [edu.postgrespro.ru/dev1-12/dev1_08_sql_func.html](https://edu.postgrespro.ru/dev1-12/dev1_08_sql_func.html) + ДЗ
- [DEV1-12. 09. Процедуры](https://rutube.ru/video/c34d23384d0948a74387e93c7a7f6e37/) [edu.postgrespro.ru/dev1-12/dev1_09_sql_proc.html](https://edu.postgrespro.ru/dev1-12/dev1_09_sql_proc.html) + ДЗ
- [DEV1-12. 11. Обзор и конструкции языка PL/pgSQL](https://rutube.ru/video/be67209d5f6eee34976a5c741e75bff8/) - достаточно ознакомиться

## Python
2 курса по Python - простой и расширенный
["Поколение Python": курс для начинающих – Stepik](https://stepik.org/course/58852/info)
["Поколение Python": курс для продвинутых – Stepik](https://stepik.org/course/68343/info)
Кратко(???) про ООП, менеджеры контекста
Pandas
Jupyter Lab - кратко

Полезно, но дороговато и не обязательно: хорошее комбо SQL + Python: ["Поколение Python": профи + ООП + SQL – Stepik](https://stepik.org/course/233341/promo?search=7181036958)

Цель - LiveCoding простых задач Python, далее нужно будет для создания DAG Airflow

## Технические навыки
### Запись встреч
OBS Studio
### Git
Книга: [Pro Git](https://git-scm.com/book/ru/v2) - указать главы для чтения
[Курс работы с Git и GitLab - ЭФКО ЦПР | YouTube плейлист](https://www.youtube.com/playlist?list=PLbf8m52BvqlFlblJqQKPuEU26pwgqe7zK) - указать номера лекций для просмотра и повторения за лектором.
Целевой уровень знания - понимание процесса GitFlow. Как создать ветку, влить изменения в другие ветки. Понимание, зачем.
На собесах обычно не спрашивают, но нужно в работе.
### Docker
- Postgres (развертывание, допиливание, запекание в него учебной БД, выгрузка на docker hub)
- Основа для будущих домашних работ - сборка стендов. Хранение в Git и проверка ментором.
### Методы разработки (водопад, scrum, kanban)
Найти краткие обзоры методов разработки. Потом проговорить на занятии, когда что используется

## Airflow
Один из основных инструменов.
Найти объяснение для менти...

## Курсовая работа
### Стенд в Docker Compose 
- Apache Airflow
    - Источник данных - TelecomX
- Postgres
- ETL
- Исходные коды всего - в Git
- Каждая новая фича разрабатывается в отдельной ветке

## Понятие сложности алгоритмов
### SQL
### Python
## Подготовка к собеседованиям
Думаем, как "сделать" опыт, от 2 лет
### Помощь в подготовке резюме
- Видео от ОМ по составлению резюме
    - [Как накрутить опыт в резюме | «Ультимативный гайд» ‪@digital_ninja‬](https://www.youtube.com/watch?v=EPuogJuYsvY)
    -  [Как писать резюме, чтобы его читали - доклад - Boosty](https://boosty.to/m0rtymerr/posts/71b02a6b-8116-466a-b945-b2ed793abd8f)
    - [Как грамотно продать себя на собеседовании / Созвон сообщества - Boosty](https://boosty.to/m0rtymerr/posts/7289cd23-60c6-4010-bb1c-a5b28dac399a)
- Попытки менти написать, моя обратная связь - итеративно
### Помощь с прохождением испытательного срока
- [Как успешно пройти испытательный срок в IT | «Ультимативный гайд» c @digital_ninja - Youtube](https://www.youtube.com/watch?v=r1lWP5rYVdk)
- [Испытательный срок - доклад - Boosty](https://boosty.to/m0rtymerr/posts/40e7f17e-022b-495c-8d03-dabbe4383b8e)
Видео по прохождению собесов от ОМ. Мои комментарии к нему, мой опыт
Первые тренировки мок собесы, обратная связь

Навыки поиска работы с HH и Habr карьера

[Как накрутить опыт в резюме | «Ультимативный гайд» ‪@digital_ninja‬](https://www.youtube.com/watch?v=EPuogJuYsvY)
[Как подтвердить опыт без трудовой / Хабр против работяг](https://www.youtube.com/watch?v=GHqABzA1zi8)
[Как успешно пройти испытательный срок в IT | «Ультимативный гайд» c @digital_ninja - Youtube](https://www.youtube.com/watch?v=r1lWP5rYVdk)

# Расширенные навыки
Поясняю, что главное - уметь пользоваться и отвечать на вопросы собесов. Уметь самому разворачивать сложные конфигурации - излишне, для этого в компаниях обычно есть DevOPS и DBA. Достаточно прочувствовать на простом docker стенде.
## Greenplum
Дать теоретический материал - разница с Postgres.
Контейнер с GreenPlum, несколько домашек по нему, чтобы прочувствовать работу распределенных запросов.
- [sergeyosechkin/greenplum Tags | Docker Hub](https://hub.docker.com/r/sergeyosechkin/greenplum/tags)
- [Как собрать Docker-образ Greengage DB | Greengage DB Docs](https://greengagedb.org/ru/docs-gg/current/use_docker.html)
В сложности с виртуалками - только если менти сильно захочет. Не буду рекомендовать.

## NiFi
Делаем отдельный docker compose Postgres + Nifi
В NiFi собираем генератор данных

## Kafka
[Лучший Гайд по Kafka для Начинающих За 1 Час - Youtube](https://www.youtube.com/watch?v=hbseyn-CfXY)
Добавляем к предыдущему docker compose Kafka. 
Строим поток данных NiFi->Kafka
Kafka->NiFi->Postgres

## dbt
Обзорная лекция, для понимания смысла

# Софт скиллы
- [Все ветви дохода в IT / Полный гайд по деньгам](https://youtube.com/live/JHClTWwK1EM)
- [Гайд как писать отзывы](https://boosty.to/m0rtymerr/posts/b04040ec-0f46-4524-9c75-188a513140ad?share=post_link)  
- [Гайд по Антистрессу](https://youtu.be/bu0YiXOKaoU)

# Тех. материалы несортировано
- [Индексы в БД - Youtube](https://www.youtube.com/watch?v=DyqtBiDrz3g)
- [Spark + Iceberg in 1 Hour - Memory Tuning, Joins, Partition - Youtube](https://www.youtube.com/watch?v=3R-SLYK-P_0)
- [Алгоритмы: теория и практика. Методы – Stepik](https://stepik.org/course/217/info)
- [Алгоритмы: теория и практика. Структуры данных – Stepik](https://stepik.org/course/1547/promo)

## Записи ОМ
- [Как пройти собеседование на программиста | Ультимативный гайд с ‪@om_nazarov‬ - Youtube](https://www.youtube.com/watch?v=tzSdiYZ52kI)
- [Как стать программистом в 2025 | «Ультимативный гайд» с ‪@om_nazarov‬](https://www.youtube.com/watch?v=6151ekTOl38)
- 


