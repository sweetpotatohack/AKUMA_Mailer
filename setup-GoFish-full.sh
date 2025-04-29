#!/bin/bash

set -e  # Автоматический выход при ошибках
set +H  # Отключаем history expansion

# --- Конфигурация ---
DEFAULT_DOMAIN="example.com"
DEFAULT_ADMIN_PORT="3333"
DEFAULT_PHISHING_PORT="80"
DEFAULT_ADMIN_IP="0.0.0.0"  # Для доступа извне

# --- Проверка прав ---
if [ "$(id -u)" -ne 0 ]; then
    echo "✗ Скрипт должен запускаться с правами root!" >&2
    exit 1
fi

# --- Аргументы командной строки ---
while getopts "d:a:p:i:" opt; do
    case $opt in
        d) DOMAIN="$OPTARG" ;;
        a) ADMIN_PORT="$OPTARG" ;;
        p) PHISHING_PORT="$OPTARG" ;;
        i) ADMIN_IP="$OPTARG" ;;
        *) echo "Использование: $0 [-d domain] [-a admin_port] [-p phishing_port] [-i admin_ip]" >&2
           exit 1 ;;
    esac
done

DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}
ADMIN_PORT=${ADMIN_PORT:-$DEFAULT_ADMIN_PORT}
PHISHING_PORT=${PHISHING_PORT:-$DEFAULT_PHISHING_PORT}
ADMIN_IP=${ADMIN_IP:-$DEFAULT_ADMIN_IP}

# --- Визуальные эффекты ---
clear
tput civis  # скрыть курсор

echo -e "\e[1;35m"
cat << "EOF"
   ________              ______  __          
  / ____/ /_  ___  _____/ __/ /_/ /__  _____
 / / __/ __ \/ _ \/ ___/ /_/ __/ / _ \/ ___/
/ /_/ / / / /  __(__  ) __/ /_/ /  __/ /    
\____/_/ /_/\___/____/_/  \__/_/\___/_/     
                                             
EOF
echo -e "\e[0m"

echo -e "\e[1;36m[*] Начинаем автоматическую установку Gophish\e[0m"
echo -e "\e[1;33mДомен: \e[1;37m$DOMAIN\e[0m"
echo -e "\e[1;33mAdmin интерфейс: \e[1;37m$ADMIN_IP:$ADMIN_PORT\e[0m"
echo -e "\e[1;33mФишинг порт: \e[1;37m$PHISHING_PORT\e[0m"
sleep 2

# --- Установка зависимостей ---
echo -e "\e[1;34m[1/6] Установка зависимостей...\e[0m"
apt-get update > /dev/null
apt-get install -y git golang-go unzip > /dev/null

# --- Скачивание и сборка Gophish ---
echo -e "\e[1;34m[2/6] Скачивание Gophish...\e[0m"
if [ -d "/opt/gophish" ]; then
    rm -rf /opt/gophish
fi

git clone https://github.com/gophish/gophish.git /opt/gophish > /dev/null 2>&1
cd /opt/gophish

echo -e "\e[1;34m[3/6] Сборка Gophish...\e[0m"
go build > /dev/null 2>&1

# --- Генерация конфига ---
echo -e "\e[1;34m[4/6] Настройка конфигурации...\e[0m"
ADMIN_PASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9!@#$%^&*_?' | head -c 16)

cat > config.json <<EOF
{
    "admin_server": {
        "listen_url": "${ADMIN_IP}:${ADMIN_PORT}",
        "use_tls": true,
        "cert_path": "gophish_admin.crt",
        "key_path": "gophish_admin.key"
    },
    "phish_server": {
        "listen_url": "0.0.0.0:${PHISHING_PORT}",
        "use_tls": false
    },
    "db_name": "sqlite3",
    "db_path": "gophish.db",
    "migrations_prefix": "db/db_",
    "contact_address": "",
    "logging": {
        "filename": ""
    }
}
EOF

# --- Генерация SSL сертификатов ---
echo -e "\e[1;34m[5/6] Генерация SSL сертификатов...\e[0m"
openssl req -newkey rsa:2048 -nodes -keyout gophish_admin.key -x509 -days 365 -out gophish_admin.crt -subj "/CN=gophish.$DOMAIN" > /dev/null 2>&1

# --- Настройка systemd службы ---
echo -e "\e[1;34m[6/6] Настройка службы systemd...\e[0m"
cat > /etc/systemd/system/gophish.service <<EOF
[Unit]
Description=Gophish Phishing Framework
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/gophish
ExecStart=/opt/gophish/gophish
Restart=always
RestartSec=3
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gophish > /dev/null 2>&1
systemctl start gophish

# --- Ожидание запуска ---
sleep 5

# --- Проверка статуса ---
if ! systemctl is-active --quiet gophish; then
    echo -e "\e[1;31m[!] Ошибка запуска Gophish. Проверьте журналы: journalctl -u gophish -e\e[0m" >&2
    exit 1
fi

# --- Вывод информации ---
tput cnorm  # возвращаем курсор
echo -e "\n\e[1;32m[+] Установка Gophish завершена успешно!\e[0m"
echo -e "\e[1;33m╔══════════════════════════════════════════╗"
echo -e "║            Gophish Конфигурация           ║"
echo -e "╠══════════════════════════════════════════╣"
echo -e "║  Админ панель: https://$ADMIN_IP:$ADMIN_PORT"
echo -e "║  Логин: admin"
echo -e "║  Пароль: $ADMIN_PASSWORD"
echo -e "║  Фишинг порт: $PHISHING_PORT"
echo -e "║  Домен: $DOMAIN"
echo -e "╚══════════════════════════════════════════╝\e[0m"

# Сохранение конфигурации
CONFIG_FILE="/root/gophish_config_$DOMAIN.txt"
{
    echo "Админ панель: https://$ADMIN_IP:$ADMIN_PORT"
    echo "Логин: admin"
    echo "Пароль: $ADMIN_PASSWORD"
    echo "Фишинг порт: $PHISHING_PORT"
    echo "Домен: $DOMAIN"
    echo ""
    echo "Для смены пароля выполните:"
    echo "cd /opt/gophish && ./gophish --reset-password"
} > "$CONFIG_FILE"

echo -e "\n\e[1;36mКонфигурация сохранена в $CONFIG_FILE\e[0m"
echo -e "\e[1;33mДля первого входа используйте временный пароль выше.\e[0m"