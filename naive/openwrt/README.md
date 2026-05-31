# naive на OpenWrt

Запуск [naiveproxy](https://github.com/klzgrad/naiveproxy) как системного сервиса под управлением procd.

## Требования

- OpenWrt (любая актуальная версия с procd)
- Бинарник `naive`, собранный под архитектуру роутера и **под musl** (официальные сборки слинкованы с glibc — на OpenWrt не запустятся)
  - Проверить архитектуру: `opkg print-architecture`
  - Готовые сборки под OpenWrt ищи в релизах `klzgrad/naiveproxy` или собирай сам

## Установка автоматическая

```sh
sh <(wget -O - https://raw.githubusercontent.com/joshua1955/naiveproxy-server-setup/refs/heads/netinstall/openwrt/install.sh)
```

## Установка ручная

### 1. Скачиваем бинарник под свою архитектуру

```sh
https://github.com/klzgrad/naiveproxy/releases/latest
```

### 1.1. Устанавливаем бинарник

```sh
cp naive /usr/bin/naive
chmod +x /usr/bin/naive
file /usr/bin/naive    # проверь архитектуру и линковку
```

### 2. UCI-конфиг

`/etc/config/naive`:

```
config naive 'main'
    option enabled '1'
    option listen 'socks://127.0.0.1:1080'
    option proxy 'https://user:pass@example.com'
```

Опции:

| опция       | назначение                                | по умолчанию |
|-------------|-------------------------------------------|--------------|
| `enabled`   | `1`/`0` — включить сервис                 | `1`          |
| `listen`    | адрес локального прокси (socks/http)      | —            |
| `proxy`     | upstream-URL naive-сервера                | —            |

### 3. Init-скрипт

`/etc/init.d/naive` — см. файл в этом репозитории.

```sh
chmod +x /etc/init.d/naive
/etc/init.d/naive enable
/etc/init.d/naive start
```

## Управление

```sh
/etc/init.d/naive start
/etc/init.d/naive stop
/etc/init.d/naive restart
/etc/init.d/naive reload     # перечитать UCI, перегенерить конфиг
/etc/init.d/naive status
/etc/init.d/naive enable     # автозапуск при загрузке
/etc/init.d/naive disable
```

Изменить настройки:

```sh
uci set naive.main.proxy='https://newuser:newpass@host.com'
uci commit naive
/etc/init.d/naive reload
```
## Подключение naive c openwrt 
![Настройка naive в podkop](image.png)

## Как это работает

- При старте init-скрипт читает UCI (`/etc/config/naive`) и генерирует JSON-конфиг в `/var/etc/naive.json` (tmpfs — не пишем в overlay).
- procd запускает бинарник, отслеживает падения и автоматически рестартит (`respawn 3600 5 0`).
- `procd_add_reload_trigger` — при `uci commit naive` procd сам инициирует reload.
- stdout/stderr процесса попадают в системный лог.

## Диагностика

```sh
logread -e naive | tail -30          # логи сервиса
ps w | grep naive                    # запущен ли процесс
cat /var/etc/naive.json              # проверить сгенерированный конфиг
/usr/bin/naive /var/etc/naive.json   # запуск вручную — видны ошибки сразу
```

Частые проблемы:

- **Процесса нет, в логах ничего** — почти всегда несовместимость бинарника: glibc вместо musl, либо не та архитектура. `ldd /usr/bin/naive` или `file` покажут.
- **`permission denied`** — `chmod +x /usr/bin/naive`.
- **Падает сразу после старта** — битый JSON или невалидный `proxy`-URL. Запусти руками.
- **Меняли UCI, ничего не применилось** — забыли `uci commit naive` или `reload`.

## Файлы

```
/usr/bin/naive          бинарник
/etc/config/naive       UCI-конфиг (правится пользователем)
/etc/init.d/naive       init-скрипт procd
/var/etc/naive.json     сгенерированный JSON (создаётся автоматически)
```
