#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${RED}[-] Проверка порта 80...${NC}"
PID=$(lsof -ti tcp:80 || true)

if [ -z "$PID" ]; then
    echo -e "${GREEN}[+] Порт 80 свободен. Продолжаю установку.${NC}"
else
    echo -e "${RED}[-] Порт 80 занят. Завершаю процесс PID: $PID${NC}"
    kill -9 "$PID"
    echo -e "${GREEN}[+] Процесс завершён. Продолжаю установку.${NC}"
fi

echo -e "${GREEN}[+] Скачиваю Gophish...${NC}"
wget -q https://github.com/gophish/gophish/releases/download/v0.12.1/gophish-v0.12.1-linux-64bit.zip

mkdir -p ./gophish
unzip -d ./gophish ./gophish-v0.12.1-linux-64bit.zip > /dev/null
cd ./gophish/
chmod +x gophish

echo -e "${GREEN}[+] Делаю файл исполняемым...${NC}"
chmod +x ./gophish

echo -e "${GREEN}[+] Настраиваю config.json...${NC}"
cat > config.json <<EOF
{
        "admin_server": {
                "listen_url": "0.0.0.0:3333",
                "use_tls": true,
                "cert_path": "gophish_admin.crt",
                "key_path": "gophish_admin.key",
                "trusted_origins": []
        },
        "phish_server": {
                "listen_url": "0.0.0.0:80",
                "use_tls": false,
                "cert_path": "example.crt",
                "key_path": "example.key"
        },
        "db_name": "sqlite3",
        "db_path": "gophish.db",
        "migrations_prefix": "db/db_",
        "contact_address": "",
        "logging": {
                "filename": "",
                "level": ""
        }
}
EOF

echo -e "${GREEN}[+] Запускаю Gophish...${NC}"
./gophish | while IFS= read -r line; do
    if [[ "$line" == *"error"* || "$line" == *"warning"* ]]; then
        echo -e "${RED}$line${NC}"
    else
        echo -e "${GREEN}$line${NC}"
    fi
done
