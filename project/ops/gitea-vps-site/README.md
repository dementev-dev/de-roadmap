# Эксплуатация публикации `de.dementev.space`

Этот runbook реализует спецификацию
[`2026-08-04-gitea-vps-site-publishing.md`](../../specs/2026-08-04-gitea-vps-site-publishing.md).
Команды рассчитаны на Ubuntu 26.04 и Gitea 1.27.

## Зафиксированные параметры

- Gitea Runner: `2.3.0`, Linux amd64.
- SHA256: `1e9fb1bea022fdf40993ecbc1a13e87db1bfd3d7f42666e37f15f71d840d53b3`.
- Runner: repository-scoped, метка `de-roadmap-host:host`.
- Пользователь сервиса: `gitea-runner`, без `sudo` и Docker.
- Корень публикации: `/srv/de-roadmap`.
- Хранение: текущий релиз и две предыдущие версии.
- Окружение сборки: `/var/lib/gitea-runner/venvs/site`.
- Публичный IPv4 VPS: `167.224.64.252`.

## Предварительные условия

- Есть пользователь с `sudo` и рабочий SSH-доступ к VPS.
- Есть доступ к управлению DNS-зоной `dementev.space`.
- В репозитории `ddmitry/de-roadmap` включены Gitea Actions.

## Подготовка VPS

Установить Git, HTTP-сервер, Certbot, UFW и Python venv:

```bash
sudo apt-get update
sudo apt-get install \
  ca-certificates \
  certbot \
  curl \
  git \
  jq \
  nginx \
  python3-certbot-nginx \
  python3-venv \
  ufw
```

Получить административный checkout, из которого устанавливаются tracked-файлы:

```bash
git clone https://git.dementev.space/ddmitry/de-roadmap.git
cd de-roadmap
```

Создать пользователя и каталоги:

```bash
sudo useradd \
  --system \
  --home-dir /var/lib/gitea-runner \
  --create-home \
  --shell /usr/sbin/nologin \
  gitea-runner
sudo install -d -o gitea-runner -g gitea-runner -m 0755 \
  /var/lib/gitea-runner/workspaces \
  /srv/de-roadmap \
  /srv/de-roadmap/releases
sudo install -d -o root -g root -m 0755 /etc/gitea-runner
```

Скачать runner во временный каталог, сверить checksum и установить root-owned
бинарник в `/usr/local/bin/gitea-runner`:

```bash
runner_tmp_dir=$(mktemp -d /tmp/de-roadmap-runner.XXXXXX)
curl -fsSLo "${runner_tmp_dir}/gitea-runner" \
  https://dl.gitea.com/gitea-runner/2.3.0/gitea-runner-2.3.0-linux-amd64
printf '%s  %s\n' \
  '1e9fb1bea022fdf40993ecbc1a13e87db1bfd3d7f42666e37f15f71d840d53b3' \
  "${runner_tmp_dir}/gitea-runner" \
  | sha256sum --check
sudo install -o root -g root -m 0755 \
  "${runner_tmp_dir}/gitea-runner" /usr/local/bin/gitea-runner
rm "${runner_tmp_dir}/gitea-runner"
rmdir "$runner_tmp_dir"
```

Из корня репозитория установить конфигурацию и unit:

```bash
sudo install -o root -g root -m 0644 \
  project/ops/gitea-vps-site/gitea-runner.yaml \
  /etc/gitea-runner/config.yaml
sudo install -o root -g root -m 0644 \
  project/ops/gitea-vps-site/gitea-runner.service \
  /etc/systemd/system/gitea-runner.service
sudo systemd-analyze verify /etc/systemd/system/gitea-runner.service
```

## Регистрация runner

Repository registration token получают в Gitea:
`ddmitry/de-roadmap` → Settings → Actions → Runners. Токен не сохраняют в Git
или shell history. Временный файл с токеном создают с владельцем
`gitea-runner:gitea-runner` и режимом `0600`. После регистрации файл
`/var/lib/gitea-runner/.runner` должен принадлежать тому же пользователю и
иметь режим `0600`.

Token-file должен содержать ровно 40 символов без завершающего перевода строки.
При извлечении JSON-ответа через `jq` использовать `jq --join-output '.token'`,
а не `jq --raw-output`, который добавляет newline.

```bash
sudo -u gitea-runner \
  /usr/local/bin/gitea-runner \
  --config /etc/gitea-runner/config.yaml \
  register \
  --no-interactive \
  --instance https://git.dementev.space \
  --token-file /var/lib/gitea-runner/.registration-token \
  --name de-roadmap-vps
sudo rm /var/lib/gitea-runner/.registration-token
sudo chmod 0600 /var/lib/gitea-runner/.runner
sudo systemctl daemon-reload
sudo systemctl enable --now gitea-runner
systemctl is-enabled gitea-runner
systemctl is-active gitea-runner
```

Временный файл с токеном удаляют сразу после успешной регистрации. В Gitea на
странице Settings → Actions → Runners runner `de-roadmap-vps` должен перейти в
состояние online и показывать метку `de-roadmap-host`.

## Nginx и первичная публикация

Из корня репозитория установить bootstrap-конфигурацию nginx, создать ссылку,
отключить стандартный сайт Ubuntu и только затем перечитать проверенную
конфигурацию:

```bash
sudo install -o root -g root -m 0644 \
  project/ops/gitea-vps-site/nginx.conf \
  /etc/nginx/sites-available/de-roadmap
sudo ln -s \
  /etc/nginx/sites-available/de-roadmap \
  /etc/nginx/sites-enabled/de-roadmap
sudo unlink /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

Первый server block в `nginx.conf` возвращает `404` для неизвестных HTTP Host,
не раскрывает версию nginx и отклоняет TLS handshake для IP или неизвестного
SNI. Поэтому сертификат `de.dementev.space` не выдаётся при обращении к VPS по
IP. Если проверка конфигурации не прошла, отключить новый virtual host,
восстановить стандартный сайт и перечитать проверенную конфигурацию:

```bash
sudo unlink /etc/nginx/sites-enabled/de-roadmap
sudo ln -s \
  /etc/nginx/sites-available/default \
  /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

Файл `project/ops/gitea-vps-site/nginx.conf` предназначен только для запуска до
выпуска сертификата. После выпуска сертификата Certbot изменяет установленный
virtual host. Повторная установка bootstrap-файла поверх рабочего конфига
удалит TLS-директивы.

## Окружение сборки

Скрипт `.gitea/scripts/build-site.sh` создаёт persistent venv при первом запуске
и переиспользует его в следующих сборках. `pip install` выполняется каждый раз,
чтобы применить изменения `.gitea/requirements-site.txt`, но уже установленные
версии пакетов не переустанавливаются.

## Первый деплой

В Gitea открыть Actions → Deploy MkDocs to VPS, выбрать ветку `main` и нажать
Run workflow. Job `deploy` должен завершиться успешно. Проверить опубликованный
release и локальную выдачу nginx до переключения DNS:

```bash
readlink -f /srv/de-roadmap/current
curl --fail --header 'Host: de.dementev.space' http://127.0.0.1/
```

Затем разрешить SSH, HTTP и HTTPS в UFW. Если SSH работает не на стандартном
порту `22`, сначала разрешить фактический порт вместо профиля `OpenSSH`:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable
sudo ufw status verbose
```

Ожидается политика `deny (incoming)` и разрешения только для SSH, `80/tcp` и
`443/tcp`.

## DNS и TLS

1. Уменьшить TTL записи `de.dementev.space`.
2. Направить `A` на VPS; удалить или корректно направить `AAAA`.
3. Убедиться, что сайт доступен извне по HTTP:

    ```bash
    curl --fail --head http://de.dementev.space/
    ```

4. Выпустить сертификат и включить перенаправление HTTP на HTTPS:

    ```bash
    sudo certbot --nginx \
      --non-interactive \
      --agree-tos \
      --email me@dementev.space \
      --redirect \
      -d de.dementev.space
    ```

5. В созданном Certbot HTTP-блоке для `de.dementev.space` добавить
   `server_tokens off;`, затем проверить и перечитать конфигурацию:

    ```bash
    sudoedit /etc/nginx/sites-available/de-roadmap
    sudo nginx -t
    sudo systemctl reload nginx
    ```

6. Проверить перенаправление, HTTPS, сертификат и автоматическое продление:

    ```bash
    curl --head http://de.dementev.space/
    curl --fail --head https://de.dementev.space/
    ! curl --insecure --head https://167.224.64.252/
    sudo certbot certificates
    systemctl is-enabled certbot.timer
    systemctl is-active certbot.timer
    ```

   Ожидаются `301 Moved Permanently`, затем `200 OK`, отказ TLS по IP,
   действующий сертификат и состояния таймера `enabled` и `active`.

7. Вернуть обычный DNS TTL.

## Проверка и откат

Активная версия определяется ссылкой `/srv/de-roadmap/current`. Для ручного
отката сначала выбрать точный release id из сохранённых каталогов, затем создать
временную ссылку и атомарно заменить `current`:

```bash
find /srv/de-roadmap/releases \
  -mindepth 1 \
  -maxdepth 1 \
  -type d \
  -printf '%f\n' \
  | sort

rollback_release='<COMMIT_SHA>-<RUN_ID>'
rollback_link='/srv/de-roadmap/.current.rollback'
[[ "$rollback_release" =~ ^[0-9a-f]{40}-[0-9]+$ ]]
sudo test -d "/srv/de-roadmap/releases/${rollback_release}"
sudo test ! -e "$rollback_link"
sudo -u gitea-runner \
  ln -s "releases/${rollback_release}" "$rollback_link"
sudo -u gitea-runner \
  mv -Tf "$rollback_link" /srv/de-roadmap/current
readlink -f /srv/de-roadmap/current
curl --fail --head https://de.dementev.space/
```

Откат не удаляет более новые releases. Перед их ручным удалением всегда
проверять результат `readlink -f /srv/de-roadmap/current`.

Диагностика:

```bash
sudo systemctl status gitea-runner
sudo journalctl -u gitea-runner
sudo nginx -t
readlink -f /srv/de-roadmap/current
curl --fail --head https://de.dementev.space/
```
