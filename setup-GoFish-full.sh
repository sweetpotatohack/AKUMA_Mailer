#!/bin/bash

set -e

DOMAIN="fish.AKUMA.fun"   # ⚠️ Укажи свой домен
EMAIL="AKUMA@yandex.ru"             # ⚠️ Укажи свой email (для Let's Encrypt)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}[-] Проверка порта 3333...${NC}"
PID3333=$(lsof -ti tcp:3333 || true)

if [ -z "$PID3333" ]; then
    echo -e "${GREEN}[+] Порт 3333 свободен. Продолжаю установку.${NC}"
else
    echo -e "${RED}[-] Порт 3333 занят. Завершаю процесс PID: $PID3333${NC}"
    kill -9 "$PID3333"
    echo -e "${GREEN}[+] Процесс завершён. Продолжаю установку.${NC}"
fi

echo -e "${RED}[-] A single phishing link can topple empires....${NC}"
PID=$(lsof -ti tcp:80 || true)

if [ -z "$PID" ]; then
    echo -e "${GREEN}[+] Порт 80 свободен. Продолжаю установку.${NC}"
else
    echo -e "${RED}[-] Порт 80 занят. Завершаю процесс PID: $PID${NC}"
    kill -9 "$PID"
    echo -e "${GREEN}[+] Процесс завершён. Продолжаю установку.${NC}"
fi

echo -e "${GREEN}[+] Устанавливаю certbot...${NC}"
sudo apt update
sudo apt install -y certbot

echo -e "${GREEN}[+] Получаю сертификат Let's Encrypt для $DOMAIN...${NC}"
sudo certbot certonly --standalone --agree-tos --non-interactive --preferred-challenges http -d "$DOMAIN" -m "$EMAIL"

CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"

if [ ! -f "$CERT_PATH" ] || [ ! -f "$KEY_PATH" ]; then
    echo -e "${RED}[!] Не удалось получить TLS-сертификат. Прерываю установку.${NC}"
    exit 1
fi

echo -e "${GREEN}[+] Сертификаты успешно получены.${NC}"
echo -e "${GREEN}[+] Скачиваю Gophish...${NC}"
wget -q https://github.com/gophish/gophish/releases/download/v0.12.1/gophish-v0.12.1-linux-64bit.zip

mkdir -p ./gophish
unzip -d ./gophish ./gophish-v0.12.1-linux-64bit.zip > /dev/null
cd ./gophish/
chmod +x gophish

echo -e "${GREEN}[+] Делаю файл исполняемым...${NC}"
chmod +x ./gophish

echo -e "${GREEN}[+] Настраиваю config.json с сертификатами Let's Encrypt...${NC}"
cat > config.json <<EOF
{
        "admin_server": {
                "listen_url": "0.0.0.0:3333",
                "use_tls": true,
                "cert_path": "$CERT_PATH",
                "key_path": "$KEY_PATH",
                "trusted_origins": []
        },
        "phish_server": {
                "listen_url": "0.0.0.0:443",
                "use_tls": false,
                "cert_path": "",
                "key_path": ""
        },
        "db_name": "sqlite3",
        "db_path": "gophish.db",
        "migrations_prefix": "db/db_",
        "contact_address": "$EMAIL",
        "logging": {
                "filename": "",
                "level": ""
        }
}
EOF

echo -e "${GREEN}[+] Запускаю Gophish в фоне...${NC}"
nohup ./gophish > gophish.log 2>&1 &

sleep 5

echo -e "${YELLOW}[?] Gophish работает на: https://$DOMAIN:3333 (админка) и https://$DOMAIN (фишинг)${NC}"

PASS=$(grep "Please login with the username" gophish.log | tail -n1)
if [ -n "$PASS" ]; then
    echo -e "${GREEN}[+] $PASS${NC}"
else
    echo -e "${RED}[!] Не удалось найти логин и пароль. Проверьте файл gophish.log${NC}"
fi

# --- Автопродление сертификата ---
echo -e "${GREEN}[+] Настраиваю автопродление TLS сертификата...${NC}"
CRON_CMD="0 3 * * * certbot renew --quiet && systemctl restart gophish"

# Добавляем в крон, если ещё не добавлено
(crontab -l 2>/dev/null | grep -v 'certbot renew'; echo "$CRON_CMD") | crontab -

echo -e "${GREEN}[✓] Установка завершена. Сертификаты будут продлеваться автоматически.${NC}"
