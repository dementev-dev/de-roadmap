#!/bin/bash

# создадим папку проекта и подпапку для init-скриптов
mkdir -p initdb
rm -rf initdb/*.sql

# пример: «средняя» демо-база (3 месяца данных, ~700 МБ после загрузки)
wget https://edu.postgrespro.com/demo-medium-en.zip
unzip demo-medium-en.zip -d initdb
rm -f demo-medium-en.zip

# переименуем SQL для удобства
# (имя исходного файла содержит дату; это нормально)
mv initdb/demo-*.sql initdb/01_bookings.sql
cat > initdb/00_init.sql <<'SQL'
CREATE DATABASE demo;
SQL
