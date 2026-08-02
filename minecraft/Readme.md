# Инструкция по поднятию сервера Minecraft на Docker

Пошаговое руководство по развертыванию собственного сервера Minecraft в изолированном контейнере Docker на арендованном VPS.

---

## Шаг 1. Аренда сервера
Для комфортной игры рекомендуется арендовать виртуальный сервер (VPS) с установленной операционной системой **Ubuntu**. 
* Вы можете воспользоваться проверенным хостингом по реферальной ссылке: [Hip.hosting](https://hip.hosting/?code=403677fb80de36e50a19).

После покупки подключитесь к вашему серверу по SSH (через пароль или SSH-ключ).

---

## Шаг 2. Автоматическая установка через Bash-скрипт
Вы можете развернуть и настроить весь сервер одной командой, используя готовый скрипт автоматизации. 

### Вариант А: Быстрый запуск одной командой (через curl)

```bash
curl -sSL https://raw.githubusercontent.com/joshua1955/docs/refs/heads/main/minecraft/install.sh | bash
```

### Вариант Б: Ручной запуск скрипта
Вы также можете создать файл скрипта вручную на сервере:

1. Создайте файл:
   ```bash
   nano install.sh
   ```
2. Вставьте в него следующий код:

```bash
#!/bin/bash
set -e

echo "[+] Обновление системы и установка зависимостей..."
sudo apt update && sudo apt upgrade -y
sudo apt install ca-certificates curl ufw fail2ban -y

echo "[+] Добавление официального GPG-ключа и репозитория Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<DOCKER_EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
DOCKER_EOF

sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

echo "[+] Настройка сетевой безопасности (UFW)..."
sudo ufw allow 22/tcp
sudo ufw allow 25565/tcp
sudo ufw --force enable

echo "[+] Создание конфигурации Docker..."
mkdir -p ~/minecraft-server && cd ~/minecraft-server

cat << 'COMPOSE_EOF' > docker-compose.yml
services:
  mc:
    image: itzg/minecraft-server
    pull_policy: daily
    tty: true
    stdin_open: true
    ports:
      - "25565:25565"
    environment:
      VERSION: 1.21.11
      EULA: "TRUE"
      ONLINE_MODE: "FALSE"
      OPS: "kata,RedJoshua1955"
    volumes:
      - ./data:/data
COMPOSE_EOF

echo "[+] Запуск сервера Minecraft..."
docker compose up -d
echo "[✓] Готово! Сервер успешно запущен."
```

3. Сохраните файл (`Ctrl + O`, `Enter`, `Ctrl + X`) и запустите его:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

---

## Шаг 3. Подключение и настройка белого списка (Whitelist)
После завершения установки откройте клиент Minecraft, добавьте IP-адрес вашего VPS и зайдите на сервер.

Для защиты сервера от нежелательных гостей активируйте белый список:

1. Выполните команды в терминале хоста из папки с сервером (или через консоль контейнера):
   ```bash
   cd ~/minecraft-server
   docker compose exec mc rcon-cli /whitelist on
   docker compose exec mc rcon-cli /whitelist add kata
   ```
2. Либо сделайте это прямо из игры (если вы указаны в операторах `OPS`):
   ```text
   /whitelist on
   /whitelist add kata
   ```
