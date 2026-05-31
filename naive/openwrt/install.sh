#!/bin/sh

# Установка naiveproxy на OpenWrt: скачивает последний релиз под архитектуру роутера,
# ставит бинарник, UCI-конфиг и init-скрипт, включает автозапуск.
set -eu

REPO="klzgrad/naiveproxy"
BIN_DST="/usr/bin/naive"
INIT_DST="/etc/init.d/naive"
UCI_DST="/etc/config/naive"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# --- 1. Архитектура ---------------------------------------------------------
. /etc/os-release
ARCH="${OPENWRT_ARCH:-}"
[ -n "$ARCH" ] || { echo "Не удалось определить OPENWRT_ARCH"; exit 1; }
echo ">>> Архитектура: $ARCH"

# --- 2. Зависимости ---------------------------------------------------------
need() { command -v "$1" >/dev/null 2>&1; }

if need curl; then
    DL="curl -fsSL"
elif need wget; then
    # проверим что wget умеет https (wget-ssl)
    if wget --help 2>&1 | grep -q https; then
        DL="wget -qO-"
    else
        echo ">>> Ставлю wget-ssl..."
        opkg update && opkg install wget-ssl
        DL="wget -qO-"
    fi
else
    echo ">>> Ставлю curl..."
    opkg update && opkg install curl
    DL="curl -fsSL"
fi

if ! need xz; then
    echo ">>> Ставлю xz..."
    opkg update && opkg install xz
fi

if ! tar --help 2>&1 | grep -q GNU; then
    echo ">>> Ставлю GNU tar..."
    opkg update && opkg install tar
fi


# --- 3. Найти ассет в последнем релизе --------------------------------------
echo ">>> Запрос последнего релиза $REPO..."
API_URL="https://api.github.com/repos/$REPO/releases/latest"
ASSET_URL="$(
    $DL "$API_URL" \
    | grep -oE '"browser_download_url"[^"]*"[^"]+"' \
    | grep -oE 'https://[^"]+' \
    | grep -- "-openwrt-${ARCH}-static\.tar\.xz$" \
    | head -n1
)"

[ -n "$ASSET_URL" ] || {
    echo "Не нашёл ассет под -openwrt-${ARCH}-static.tar.xz в последнем релизе."
    echo "Глянь вручную: https://github.com/$REPO/releases/latest"
    exit 1
}
echo ">>> Ассет: $ASSET_URL"

# --- 4. Скачать и распаковать -----------------------------------------------
cd "$TMPDIR"
echo ">>> Скачиваю..."
case "$DL" in
    curl*) curl -fsSL -o naive.tar.xz "$ASSET_URL" ;;
    wget*) wget -qO naive.tar.xz "$ASSET_URL" ;;
esac

echo ">>> Распаковка..."
tar -xvf naive.tar.xz
NAIVE_BIN="$(find . -type f -name naive | head -n1)"
[ -n "$NAIVE_BIN" ] || { echo "В архиве не нашёл бинарник 'naive'"; exit 1; }

# --- 5. Установка бинарника -------------------------------------------------
echo ">>> Установка $BIN_DST"
cp "$NAIVE_BIN" "$BIN_DST"
chmod 0755 "$BIN_DST"

# --- 6. UCI-конфиг (только если нет) ----------------------------------------
if [ ! -f "$UCI_DST" ]; then
    echo ">>> Создаю $UCI_DST (шаблон — отредактируй proxy!)"
    cat > "$UCI_DST" <<'EOF'
config naive 'main'
    option enabled '1'
    option listen 'socks://127.0.0.1:1080'
    option proxy 'https://user:pass@example.com'
EOF
else
    echo ">>> $UCI_DST уже существует — не трогаю"
fi

# --- 7. Init-скрипт ---------------------------------------------------------
echo ">>> Установка $INIT_DST"
cat > "$INIT_DST" <<'EOF'
#!/bin/sh /etc/rc.common
# shellcheck disable=SC2034,SC2154

START=99
STOP=10
USE_PROCD=1

PROG=/usr/bin/naive
CONF_DIR=/var/etc
CONF_FILE=$CONF_DIR/naive.json

script=$(readlink "$initscript")
NAME="$(basename ${script:-$initscript})"

gen_config() {
    local listen proxy
    config_get listen "main" "listen"
    config_get proxy  "main" "proxy"

    mkdir -p "$CONF_DIR"
    {
        echo "{"
        printf '  "listen": "%s",\n' "$listen"
        printf '  "proxy": "%s"\n'   "$proxy"
        echo "}"
    } > "$CONF_FILE"
}

start_service() {
    config_load "$NAME"

    local enabled
    config_get_bool enabled "main" "enabled" 1
    [ "$enabled" -eq 1 ] || return 1

    gen_config

    procd_open_instance
    procd_set_param command "$PROG" "$CONF_FILE"
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn 3600 5 0
    procd_set_param file "$CONF_FILE"
    procd_close_instance
}

reload_service() {
    stop
    start
}

service_triggers() {
    procd_add_reload_trigger "$NAME"
}
EOF
chmod +x "$INIT_DST"

# --- 8. Запуск --------------------------------------------------------------
"$INIT_DST" enable
"$INIT_DST" restart

sleep 3
if pidof naive >/dev/null; then
    echo ">>> naive запущен. Версия:"
    "$BIN_DST" --version 2>/dev/null || true
    echo ">>> Логи: logread -e naive"
else
    echo "!!! naive не запустился. Смотри логи:"
    logread -e naive | tail -20
    exit 1
fi
