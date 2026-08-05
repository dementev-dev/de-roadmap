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

## Подготовка VPS

Установить HTTP-сервер и Certbot:

```bash
sudo apt-get update
sudo apt-get install nginx certbot python3-certbot-nginx python3-venv
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
```

Временный файл с токеном удаляют сразу после успешной регистрации.

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

До первого workflow можно собрать сайт вручную и опубликовать его тем же
скриптом с тестовым release id. Проверка до переключения DNS:

```bash
curl --header 'Host: de.dementev.space' http://127.0.0.1/
```

После локальной проверки разрешить профили `Nginx Full` в UFW. До этого
публичные порты `80/tcp` и `443/tcp` должны оставаться закрытыми.

Файл `project/ops/gitea-vps-site/nginx.conf` предназначен только для запуска до
выпуска сертификата. После выпуска сертификата Certbot изменяет установленный
virtual host. Повторная установка bootstrap-файла поверх рабочего конфига
удалит TLS-директивы.

## Окружение сборки

Скрипт `.gitea/scripts/build-site.sh` создаёт persistent venv при первом запуске
и переиспользует его в следующих сборках. `pip install` выполняется каждый раз,
чтобы применить изменения `.gitea/requirements-site.txt`, но уже установленные
версии пакетов не переустанавливаются.

## DNS и TLS

1. Уменьшить TTL записи `de.dementev.space`.
2. Направить `A` на VPS; удалить или корректно направить `AAAA`.
3. Убедиться, что сайт доступен извне по HTTP.
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
отката создать временную ссылку на нужный каталог в `releases/` и атомарно
заменить `current` через `mv -Tf`. Перед удалением релиза всегда проверять
результат `readlink -f /srv/de-roadmap/current`.

Диагностика:

```bash
systemctl status gitea-runner
journalctl -u gitea-runner
nginx -t
curl --header 'Host: de.dementev.space' http://127.0.0.1/
```
