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
