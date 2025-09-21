# GreenPlum Cluster Configuration
Собран на основе https://github.com/woblerr/docker-greenplum

## Обзор

Конфигурация GreenPlum была переконфигурирована для работы с кластером из 3 узлов:
- **1 Master-узел** (`gp-master`) - координирует работу кластера
- **2 Segment-узла** (`gp-segment-1`, `gp-segment-2`) - хранят данные без зеркал

## Архитектура

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   gp-master     │    │  gp-segment-1   │    │  gp-segment-2   │
│   (Master)      │◄──►│   (Segment)     │    │   (Segment)     │
│   Port: 5432    │    │   Port: 6000    │    │   Port: 6001    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Компоненты

### Docker Services

1. **gp-master** - Master-узел GreenPlum
   - Порт: 5432 (внешний доступ)
   - Роль: Координация запросов и управление кластером

2. **gp-segment-1** - Первый сегмент
   - Порт: 6000 (внутренний)
   - Роль: Хранение данных

3. **gp-segment-2** - Второй сегмент
   - Порт: 6001 (внутренний)
   - Роль: Хранение данных

### Конфигурационные файлы

- `greenplum/config/gpinitsystem_config` - Основная конфигурация кластера
- `greenplum/config/hostfile` - Список всех хостов кластера
- `greenplum/config/segment_hostfile` - Список только сегмент-хостов
- `greenplum/config/init_cluster.sh` - Скрипт инициализации кластера

## Запуск

```bash
# Запуск всего стека
docker-compose up -d

# Проверка статуса
docker-compose ps

# Просмотр логов
docker-compose logs gp-master
docker-compose logs gp-segment-1
docker-compose logs gp-segment-2
```

## Подключение к GreenPlum

```bash
# Подключение к master-узлу
docker exec -it gp_master psql -U gpadmin -d gpadmin

# Или через внешний порт
psql -h localhost -p 5432 -U gpadmin -d gpadmin
```

## Проверка кластера

```bash
# Проверка статуса кластера
docker exec -it gp_master gpstate -s

# Проверка сегментов
docker exec -it gp_master gpstate -e

# Проверка конфигурации
docker exec -it gp_master gpconfig -s
```

## Особенности конфигурации

1. **Без зеркал** - Сегменты не имеют зеркальных копий для упрощения архитектуры
2. **Изолированная сеть** - Все узлы GreenPlum работают в отдельной сети `greenplum-network`
3. **Автоматическая инициализация** - Кластер автоматически инициализируется при первом запуске
4. **Отдельные volumes** - Каждый узел имеет свой собственный volume для данных

## Troubleshooting

### Если кластер не запускается:

1. Проверьте логи:
```bash
docker-compose logs gp-master
```

2. Проверьте доступность сегментов:
```bash
docker exec -it gp_master ping gp-segment-1
docker exec -it gp_master ping gp-segment-2
```

3. Пересоздайте кластер:
```bash
docker-compose down -v
docker-compose up -d
```

### Если Airflow не может подключиться:

Убедитесь, что Airflow подключается к `gp-master:5432`, а не к старому сервису `greenplum`.

## Масштабирование

Для добавления дополнительных сегментов:

1. Добавьте новый сервис в `docker-compose.yml`
2. Обновите `gpinitsystem_config`
3. Обновите `hostfile` и `segment_hostfile`
4. Пересоздайте кластер
