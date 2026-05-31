# NaiveProxy — установка и настройка

  ---

  ## Требования

  **Сервер**
  - AlmaLinux 10 (RHEL/Rocky/CentOS 10 — должно подойти)
  - 1 vCPU, 1 ГБ RAM, 10 ГБ диска
  - Архитектура `x86_64` или `aarch64`

  **Перед установкой**
  - VPS с публичным IP
  - Домен или поддомен, A-запись которого указывает на этот IP
  - Клиент: Karing, NekoBox, Hiddify, NekoRay или V2RayN

  ---

  ## Быстрая установка (рекомендуется)

  Скрипт спросит домен, email и количество пользователей, затем сам соберёт Caddy с
  naive-плагином, настроит firewall, BBR, SELinux и systemd.

  ```bash
  bash <(curl -fsSL https://raw.githubusercontent.com/joshua1955/naiveproxy-server-setup/refs/heads/main/install.sh)
  ```

  > Перед запуском полезно посмотреть код скрипта по той же ссылке.

  После завершения логины, пароли и готовые ссылки лежат в:

  ```bash
  cat /root/naiveproxy-users.txt
  ```

  ---

  ## Ручная установка

  ### 1. Обновление и базовые пакеты

  ```bash
  dnf -y update
  dnf -y install dnf-plugins-core epel-release
  dnf -y install curl wget git openssl ca-certificates firewalld iproute tar
  policycoreutils-python-utils
  ```

  ### 2. Включение BBR

  BBR — современный алгоритм управления перегрузкой TCP. Держит скорость даже при
  небольших потерях пакетов.

  ```bash
  cat > /etc/sysctl.d/99-bbr.conf <<'EOF'
  net.core.default_qdisc=fq
  net.ipv4.tcp_congestion_control=bbr
  EOF

  sysctl --system
  sysctl net.ipv4.tcp_congestion_control   # должно вывести bbr
  ```

  ### 3. Firewall

  Открываем только нужное: SSH (22), HTTP (80, для выпуска TLS) и HTTPS (443).

  ```bash
  systemctl enable --now firewalld
  firewall-cmd --permanent --add-service=ssh
  firewall-cmd --permanent --add-service=http
  firewall-cmd --permanent --add-service=https
  firewall-cmd --reload
  ```

  ### 4. Установка Go

  Go нужен только для сборки Caddy с плагином — после сборки его можно удалить.

  ```bash
  GO_VERSION=$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)
  wget "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
  rm -rf /usr/local/go
  tar -C /usr/local -xzf /tmp/go.tar.gz

  echo 'export PATH=$PATH:/usr/local/go/bin:/root/go/bin' >> /root/.profile
  source /root/.profile

  go version
  ```

  > Для ARM-серверов замените `linux-amd64` на `linux-arm64`.

  ### 5. Сборка Caddy с naive-плагином

  Стандартный Caddy не умеет работать как forward-прокси с маскировкой под Chrome —
  нужен плагин `klzgrad/forwardproxy@naive`. Сборка занимает 5–7 минут.

  ```bash
  go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

  mkdir -p /root/tmp
  export TMPDIR=/root/tmp
  cd /root

  ~/go/bin/xcaddy build \
    --with
  github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive

  install -m 0755 /root/caddy /usr/bin/caddy
  caddy version
  ```

  ### 6. SELinux

  На AlmaLinux SELinux включён по умолчанию — нужно разрешить кастомному бинарю Caddy
  ходить в сеть и слушать привилегированные порты.

  ```bash
  semanage fcontext -a -t bin_t '/usr/bin/caddy'
  restorecon -v /usr/bin/caddy
  setsebool -P httpd_can_network_connect 1
  ```

  ### 7. Генерация логина и пароля

  Сохраните вывод — он понадобится для клиента.

  ```bash
  echo "Логин:  $(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 16)"
  echo "Пароль: $(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 24)"
  ```

  ### 8. Страница-заглушка

  Чтобы при заходе на домен в браузере отображался обычный сайт, а не пустая страница
  или ошибка.

  ```bash
  mkdir -p /var/www/html /etc/caddy

  cat > /var/www/html/index.html <<'EOF'
  <!DOCTYPE html><html><head><meta charset="utf-8"><title>Loading</title><style>body{b
  ackground:linear-gradient(135deg,#0f172a,#1e293b);height:100vh;margin:0;display:flex
  ;flex-direction:column;align-items:center;justify-content:center;font-family:sans-se
  rif}.spinner{width:40px;height:40px;border-radius:50%;border:3px solid
  rgba(255,255,255,0.12);border-top-color:#38bdf8;animation:spin 0.8s linear
  infinite;margin-bottom:25px;box-shadow:0 0 18px rgba(56,189,248,0.25)}@keyframes
  spin{to{transform:rotate(360deg)}}.t{color:#cbd5e1;font-size:13px;letter-spacing:3px
  ;font-weight:600}</style></head><body><div class="spinner"></div><div
  class="t">CONNECTING</div></body></html>
  EOF
  ```

  ### 9. Caddyfile

  Замените `your.domain.com`, `your@email.com`, `YOUR_LOGIN`, `YOUR_PASSWORD` на свои
  значения. Отступы важны.

  ```bash
  cat > /etc/caddy/Caddyfile <<'EOF'
  {
    order forward_proxy before file_server
   log {
       exclude http.log.error # Avoid logging user activity
   }

  }

  :443, your.domain.com {
    tls your@email.com
    encode
    forward_proxy {
      basic_auth YOUR_LOGIN YOUR_PASSWORD
      hide_ip
      hide_via
      probe_resistance
    }

    file_server {
      root /var/www/html
    }
  }
  EOF

  caddy validate --config /etc/caddy/Caddyfile
  ```

  ### 10. systemd-юнит

  Автозапуск при ребуте и автоматический рестарт при падении.

  ```bash
  cat > /etc/systemd/system/caddy.service <<'EOF'
  [Unit]
  Description=Caddy with NaiveProxy
  Documentation=https://caddyserver.com/docs/
  After=network.target network-online.target
  Requires=network-online.target

  [Service]
  Type=notify
  User=root
  Group=root
  ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
  ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --force
  TimeoutStopSec=5s
  LimitNOFILE=1048576
  LimitNPROC=512
  PrivateTmp=true
  ProtectSystem=full
  AmbientCapabilities=CAP_NET_BIND_SERVICE
  Restart=always
  RestartSec=5s

  [Install]
  WantedBy=multi-user.target
  EOF

  systemctl daemon-reload
  systemctl enable --now caddy
  systemctl status caddy
  ```

  В логах должно появиться `certificate obtained successfully` — значит TLS-сертификат
   от Let's Encrypt получен.

  ---

  ## Подключение клиента

  Сформируйте ссылку, подставив свои значения:

  ```
  naive+https://YOUR_LOGIN:YOUR_PASSWORD@your.domain.com:443
  ```

  Скопируйте её и в клиенте выберите **«Импорт из буфера обмена»**. Для NekoBox
  предварительно установите naive-плагин со страницы релизов.

  ### Поддерживаемые клиенты

  | Платформа | Клиент   | Где взять |
  |-----------|----------|-----------|
  | iOS       | Karing   | [App Store](https://apps.apple.com/us/app/karing/id6472431552) |
  | Android   | NekoBox  | [GitHub](https://github.com/MatsuriDayo/NekoBoxForAndroid/releases) |
  | Android   | Karing   | [GitHub](https://github.com/KaringX/karing/releases/) |
  | Windows   | Hiddify  | [GitHub](https://github.com/hiddify/hiddify-app/releases) |
  | Windows   | NekoRay  | [GitHub](https://github.com/MatsuriDayo/nekoray/releases) |
  | Windows   | V2RayN   | [GitHub](https://github.com/2dust/v2rayN/releases) |

  ---

  ## Управление сервером

  ```bash
  # статус
  systemctl status caddy

  # логи в реальном времени
  journalctl -u caddy -f

  # рестарт после правок
  systemctl restart caddy

  # мягкая перезагрузка без обрыва соединений
  caddy reload --config /etc/caddy/Caddyfile

  # валидация конфига
  caddy validate --config /etc/caddy/Caddyfile

  # проверить, что 443 слушается
  ss -tlnp | grep 443
  ```

  ---

  ## Добавление пользователей

  В блоке `forward_proxy` файла `/etc/caddy/Caddyfile` добавьте новую строку
  `basic_auth`:

  ```
  forward_proxy {
    basic_auth LOGIN_1 PASSWORD_1
    basic_auth LOGIN_2 PASSWORD_2
    hide_ip
    hide_via
    probe_resistance
  }
  ```

  Применить без обрыва соединений:

  ```bash
  caddy reload --config /etc/caddy/Caddyfile
  ```

  > Один логин можно использовать на любом количестве устройств одновременно — лимитов
   нет.

  ---

  ## Решение проблем

  | Симптом | Что проверить |
  |---------|---------------|
  | `certificate obtaining failed` | A-запись домена указывает на сервер; порт 80 открыт; домен распространился (`dig your.domain.com`) |
  | `bind: permission denied` | На AlmaLinux — выполните шаг про SELinux (`semanage` + `restorecon`) |
  | Клиент не подключается | Сверьте логин/пароль/домен в ссылке; `journalctl -u caddy-f` покажет попытки |
  | Caddy не стартует после правки конфига | `caddy validate --config  /etc/caddy/Caddyfile` укажет на синтаксическую ошибку |
