# ADR: Архитектура сайта de-roadmap

> Архитектурный документ. Проектные цели и требования — в [PRD](./PRD.md).

---

## 1. Ключевые архитектурные требования

Из PRD вытекают четыре жёстких ограничения, определяющих выбор инструментов:

1. **Сайт опционален.** Репозиторий должен полноценно работать без сайта. Удалили конфиг — всё как было.
2. **Dual-compatible links.** Внутренние ссылки между `.md` файлами должны работать и на GitHub, и на сайте.
3. **Один файл = один источник правды.** Не должно быть копий или генерируемых `.md`. Редактируем один раз — рендерится везде.
4. **Zero-effort deploy.** Push в `main` → сайт обновился. Без ручных шагов, без локальной сборки.

---

## 2. Выбор генератора статического сайта

### Рассмотренные варианты

| Критерий | MkDocs Material | Docusaurus | Hugo | Astro |
|----------|----------------|------------|------|-------|
| Язык/экосистема | Python | Node.js (React) | Go | Node.js |
| Порог входа | Минимальный — `pip install`, один YAML | Средний — npm, React-компоненты | Средний — Go templates | Высокий — фреймворк |
| Поддержка Markdown «как есть» | Отличная, расширения через плагины | Хорошая, но MDX-ориентирован | Хорошая, но shortcodes вместо стандартного MD | Хорошая |
| Навигация по длинной странице | TOC sidebar из коробки | Есть, но заточен под многостраничность | Зависит от темы | Зависит от темы |
| Поиск | Встроенный (lunr.js), работает offline | Algolia (внешний сервис) или плагин | Нет из коробки | Нет из коробки |
| Тёмная тема | Из коробки, переключатель | Из коробки | Зависит от темы | Зависит от темы |
| GitHub Pages деплой | Одна команда / готовый Action | Готовый Action | Готовый Action | Готовый Action |
| Dual-compatible links | Поддерживает с настройкой `use_directory_urls` | Преобразует ссылки, может ломать GitHub | Преобразует ссылки | Преобразует ссылки |
| Один мейнтейнер, Python-стек | ✅ Идеально | ❌ Node.js | ⚠️ Go, но бинарник | ❌ Node.js |

### Решение: MkDocs Material

**Почему:**

- Python-based — совпадает со стеком автора, `pip install` и готово.
- Лучшая из коробки поддержка длинных страниц с TOC — именно наш сценарий.
- Встроенный поиск без внешних сервисов.
- Самый простой конфиг — один `mkdocs.yml`.
- Крупнейшее комьюнити среди генераторов документации, активно развивается.
- Dual-compatible links решаемы (см. раздел 4).

**Почему не Docusaurus:** Node.js-зависимость, ориентирован на многостраничные доки с MDX-компонентами — overkill для «красивый рендер Markdown». Преобразование ссылок может конфликтовать с GitHub-форматом.

**Почему не Hugo:** Быстрый, но Go-шаблоны сложнее отлаживать. Нет встроенного поиска. Для нашего объёма контента скорость сборки не критична.

**Почему не Astro:** Полноценный веб-фреймворк — избыточен. Подошёл бы, если бы мы строили маркетинговый сайт с интерактивом, но это не текущая цель.

---

## 3. Структура файлов

### Решение открытого вопроса: `docs/` vs корень репо

**Решение: `docs_dir: .` (корень репо = корень сайта), с исключениями.**

Причина: не создаём отдельную папку `docs/`, не дублируем и не перемещаем файлы. MkDocs умеет работать с корнем репо как источником, исключая ненужное.

```yaml
# mkdocs.yml (в корне репо)
docs_dir: .
```

### Решение открытого вопроса: README.md как index

**Решение: плагин `awesome-pages` или конфигурация `nav` с явным указанием.**

MkDocs по умолчанию ищет `index.md`. Но мы хотим сохранить `README.md` (GitHub его рендерит на главной репо). Есть два пути:

- **Вариант A:** Симлинк `docs/index.md → ../README.md`. Но мы не используем `docs/`.
- **Вариант B (выбран):** В `mkdocs.yml` явно указать `README.md` как главную:

```yaml
nav:
  - Роадмап: README.md
  - Моделирование данных:
    - Введение: dwh-modeling/README.md
    - SCD: dwh-modeling/SCD.md
    - Data Vault: dwh-modeling/DataVault.md
    - "Домашка: STG → DDS → DM": dwh-modeling/Homework_Customer_Status_DDS_DM.md
```

MkDocs Material корректно обрабатывает `README.md` файлы — рендерит их как `index.html` соответствующей директории.

### Исключения из сборки

Файлы и папки, которые не должны попасть на сайт:

```yaml
exclude_docs: |
  project/          # проектная документация (PRD, ADR)
  postgres-bookings/ # скрипты стенда (не контент сайта)
  AGENTS.md         # конфигурация для AI-агентов
  LICENSE           # лицензия (есть в footer)
  .gitignore
```

### Итоговая структура репо

```
de-roadmap/
├── mkdocs.yml              ← конфиг сайта (единственный новый файл в корне)
├── README.md               ← главная страница сайта И главная страница GitHub
├── dwh-modeling/
│   ├── README.md           ← подстраница «Введение в DWH»
│   ├── SCD.md              ← подстраница
│   ├── DataVault.md        ← подстраница
│   └── Homework_*.md       ← подстраница
├── postgres-bookings/      ← исключён из сайта
├── project/                ← PRD, ADR — исключены из сайта
│   ├── PRD.md
│   └── ADR.md
├── .github/
│   └── workflows/
│       └── deploy-site.yml ← CI/CD pipeline
├── AGENTS.md               ← исключён из сайта
└── LICENSE
```

---

## 4. Стратегия ссылок (Dual Compatibility)

### Проблема

GitHub рендерит ссылки вида `[текст](dwh-modeling/SCD.md)` как переход к файлу.
MkDocs по умолчанию преобразует `.md` → `.html` и может менять структуру URL.

### Решение

Комбинация настроек MkDocs:

```yaml
use_directory_urls: true  # /dwh-modeling/SCD/ вместо /dwh-modeling/SCD.html
```

И ссылки в Markdown пишем **всегда как относительные пути к `.md` файлам**:

```markdown
<!-- Это работает и на GitHub, и в MkDocs -->
[Теория про SCD](dwh-modeling/SCD.md)
[Введение в DWH](dwh-modeling/README.md)
```

MkDocs Material автоматически резолвит `.md` ссылки в правильные URL сайта.

### Кириллические якоря

GitHub генерирует якоря из кириллических заголовков с URL-encoding:
`## Базы данных` → `#базы-данных`

MkDocs Material по умолчанию делает то же самое через расширение `toc`:

```yaml
markdown_extensions:
  - toc:
      slugify: !!python/object/apply:pymdownx.slugs.slugify
        kwds:
          case: lower
      permalink: true
```

**Риск:** поведение может различаться на edge cases (спецсимволы, эмодзи в заголовках). Митигация — на этапе MVP протестировать все существующие якорные ссылки в README.

---

## 5. CI/CD Pipeline

### GitHub Actions Workflow

```yaml
# .github/workflows/deploy-site.yml
name: Deploy MkDocs to GitHub Pages

on:
  push:
    branches: [main]
  workflow_dispatch:  # ручной запуск для отладки

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.x'

      - run: pip install mkdocs-material

      - run: mkdocs build --strict
        # --strict: падает на warnings (битые ссылки, отсутствующие файлы)

      - uses: actions/upload-pages-artifact@v3
        with:
          path: site/

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

### Что даёт `--strict`

Сборка упадёт, если:
- Есть ссылка на несуществующий `.md` файл.
- Есть битый якорь.
- Есть warning от MkDocs.

Это наш автотест ссылок — бесплатно, в CI.

---

## 6. Конфигурация MkDocs Material

### Минимальный `mkdocs.yml` для MVP

```yaml
site_name: "DE Roadmap — Data Engineering с нуля до middle"
site_url: https://dementev-dev.github.io/de-roadmap/
site_description: "Роадмап по Data Engineering: SQL, Python, Airflow, Greenplum и далее"
site_author: Dmitry Dementev

repo_url: https://github.com/dementev-dev/de-roadmap
repo_name: dementev-dev/de-roadmap

docs_dir: .
site_dir: site

# Исключаем из сборки
exclude_docs: |
  project/
  postgres-bookings/
  AGENTS.md
  LICENSE
  .gitignore
  .github/
  site/

nav:
  - Роадмап: README.md
  - Моделирование данных:
    - Введение: dwh-modeling/README.md
    - SCD: dwh-modeling/SCD.md
    - Data Vault: dwh-modeling/DataVault.md
    - "Домашка: STG → DDS → DM": dwh-modeling/Homework_Customer_Status_DDS_DM.md

theme:
  name: material
  language: ru
  palette:
    - scheme: default
      primary: indigo
      accent: indigo
      toggle:
        icon: material/brightness-7
        name: Тёмная тема
    - scheme: slate
      primary: indigo
      accent: indigo
      toggle:
        icon: material/brightness-4
        name: Светлая тема
  features:
    - navigation.top          # кнопка «наверх»
    - navigation.tracking     # URL обновляется при скролле
    - search.suggest          # подсказки в поиске
    - search.highlight        # подсветка найденного
    - toc.follow              # TOC следит за скроллом
    - content.code.copy       # кнопка копирования кода

markdown_extensions:
  - toc:
      permalink: true
  - admonition                # сворачиваемые блоки (Спринт 2)
  - pymdownx.details          # для <details>
  - pymdownx.superfences      # вложенные блоки кода
  - pymdownx.highlight        # подсветка синтаксиса
  - attr_list                 # атрибуты для элементов

plugins:
  - search:
      lang: ru
```

### Что уже включено в MVP (бесплатно с Material)

- Тёмная/светлая тема с переключателем.
- Полнотекстовый поиск на русском.
- TOC (оглавление) в правом sidebar.
- Кнопка «наверх» на длинной странице.
- URL обновляется при скролле (можно дать ссылку на конкретный раздел).
- Подсветка синтаксиса в блоках кода.
- Кнопка копирования кода.
- Ссылка на GitHub-репозиторий в шапке.

---

## 7. Кастомный домен (Спринт 2)

Домен `dementev.space` уже есть. Для подключения:

1. Создать CNAME-запись: `roadmap.dementev.space → dementev-dev.github.io`.
2. Добавить файл `CNAME` в корень репо с содержимым `roadmap.dementev.space`.
3. В `mkdocs.yml` обновить `site_url`.
4. Включить HTTPS в настройках GitHub Pages.

---

## 8. Риски и митигации

| Риск | Митигация |
|------|-----------|
| `docs_dir: .` подхватывает лишние файлы | `exclude_docs` со списком исключений; `--strict` ловит проблемы |
| Кириллические якоря ведут себя по-разному | Тестируем все якорные ссылки из README при первом деплое |
| `README.md` содержит GitHub-специфичный синтаксис | Проверяем рендер; при необходимости используем MkDocs-совместимые альтернативы |
| Зависимость от `mkdocs-material` | Активный проект (30k+ stars), Python-пакет; при необходимости — заморозить версию в `requirements.txt` |
| `exclude_docs` — относительно новая фича MkDocs | Альтернатива: `.mkdocsignore` или плагин `mkdocs-exclude`; протестировать на MVP |

---

## 9. Порядок действий (Спринт 1)

1. Создать ветку `feature/site`.
2. Добавить `mkdocs.yml` в корень репо.
3. Добавить `.github/workflows/deploy-site.yml`.
4. Добавить `project/PRD.md` и `project/ADR.md`.
5. Проверить локально: `pip install mkdocs-material && mkdocs serve`.
6. Протестировать все внутренние ссылки и якоря.
7. При необходимости — адаптировать ссылки для dual compatibility.
8. Merge в `main` → автодеплой → проверить `https://dementev-dev.github.io/de-roadmap/`.
9. Включить GitHub Pages (Settings → Pages → Source: GitHub Actions).
