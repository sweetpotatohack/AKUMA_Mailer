#!/bin/bash
set -e
set +H
tput civis

# Цвета
Y="\e[1;33m"
G="\e[1;32m"
R="\e[1;31m"
C="\e[1;36m"
W="\e[1;37m"
NC="\e[0m"

# Проверка root
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${R}[!] Запустите скрипт от root!${NC}"
  exit 1
fi

# Освобождаем порт 80
echo -e "${C}[-] Проверка порта 80...${NC}"
PID=$(lsof -ti tcp:80)
if [ -n "$PID" ]; then
  echo -e "${Y}[!] Порт 80 занят, завершаем процесс PID: $PID...${NC}"
  kill -9 $PID
  sleep 1
fi

# Создаем папку
mkdir -p /opt/gophish && cd /opt/gophish

# Скачиваем Gophish
echo -e "${C}[1/5] Скачиваем Gophish...${NC}"
wget -q https://github.com/gophish/gophish/releases/download/v0.12.1/gophish-v0.12.1-linux-64bit.zip

# Распаковываем
echo -e "${C}[2/5] Распаковываем...${NC}"
unzip -q gophish-v0.12.1-linux-64bit.zip
cd gophish-v0.12.1-linux-64bit

# Создаем config.json
echo -e "${C}[3/5] Генерируем конфигурацию...${NC}"
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

# Запускаем Gophish и сохраняем вывод
echo -e "${C}[4/5] Запуск Gophish...${NC}"
./gophish > gophish.log 2>&1 &

# Ждём запуска
sleep 5

# Извлекаем логин/пароль из лога
PASSWORD=$(grep -oP 'password \K[0-9a-f]{16}' gophish.log | head -1)

# Проверка успешности
if [ -z "$PASSWORD" ]; then
  echo -e "${R}[!] Не удалось получить пароль из логов.${NC}"
  exit 1
fi

# Вывод информации
echo -e "\n${G}[✓] Установка Gophish завершена!${NC}"
echo -e "${Y}╔════════════════════════════════════════╗"
echo -e "║           Gophish Настроен             ║"
echo -e "╠════════════════════════════════════════╣"
echo -e "║ Админ панель:  ${W}https://127.0.0.1:3333${Y}"
echo -e "║ Логин:         ${W}admin${Y}"
echo -e "║ Пароль:        ${W}$PASSWORD${Y}"
echo -e "║ Фишинг порт:   ${W}80${Y}"
echo -e "╚════════════════════════════════════════╝${NC}"

# Сохраняем в файл
echo -e "https://127.0.0.1:3333\nЛогин: admin\nПароль: $PASSWORD" > /root/gophish_info.txt
echo -e "${C}Конфигурация сохранена в /root/gophish_info.txt${NC}"
tput cnorm
