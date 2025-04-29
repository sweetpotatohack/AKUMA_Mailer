#!/bin/bash

set +H  # Отключаем history expansion (!)
set -e  # Автоматически завершать скрипт при ошибках

# --- Конфигурация ---
DEFAULT_DOMAIN="example.com"
DEFAULT_USER="smtp_user"
DKIM_SELECTOR="mail"

# --- Проверка прав ---
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт должен запускаться с правами root!" >&2
    exit 1
fi

# --- Аргументы командной строки ---
while getopts "d:u:" opt; do
    case $opt in
        d) DOMAIN="$OPTARG" ;;
        u) USERNAME="$OPTARG" ;;
        *) echo "Использование: $0 [-d domain] [-u username]" >&2
           exit 1 ;;
    esac
done

DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}
USERNAME=${USERNAME:-$DEFAULT_USER}
HOSTNAME="mail.$DOMAIN"
PASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9@#%&*_' | head -c 16)

# --- Визуальные эффекты ---
clear
tput civis  # скрыть курсор

glitch_lines=(
"Ξ Запуск кибердек ядра... [ну наконец-то]"
"Ξ Внедрение системных эксплойтов... [не спрашивай откуда они]"
"Ξ Рукопожатие с нейросетью... [надеемся, что она дружелюбная]"
"Ξ Подмена MAC-адреса... ok [теперь я - принтер HP]"
"Ξ Ректификация сплайнов... ok [никто не знает, что это]"
"Ξ Инициализация модуля анализа целей... [прицел калиброван]"
"Ξ Выпуск дронов SIGINT... [вышли через Wi-Fi соседа]"
"Ξ Подключение к интерфейсу кибервойны... [настраиваю лазерную указку]"
"Ξ ████████████▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░ [10%] загрузка кофеина"
"Ξ ███████████████▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░ [42%] теряется связь с реальностью"
"Ξ ███████████████████████▓▓▓▓▓▓░░░░░░░░ [76%] синхронизация с darknet"
"Ξ ████████████████████████████████████ [100%] ты больше не человек"
)

for line in "${glitch_lines[@]}"; do
    if command -v lolcat &>/dev/null; then
        echo -ne "\e[1;32m$line\e[0m\n" | lolcat
    else
        echo -ne "\e[1;32m$line\e[0m\n"
    fi
    sleep 0.1  # Уменьшил задержку для автоматизации
done

echo ""
echo -ne "\e[1;35m┌──────────────────────────────────────────────────────┐\e[0m\n"
echo -ne "\e[1;35m│ \e[0m\e[1;36m   SMTP DEPLOYMENT MODULE :: WELCOME, OPERATIVE.   \e[0m\e[1;35m│\e[0m\n"
echo -ne "\e[1;35m└──────────────────────────────────────────────────────┘\e[0m\n"
sleep 1

# --- Основная установка ---
echo "[*] Начинаем развертывание SMTP-сервера для домена: $DOMAIN"

# 1. Установка зависимостей
echo "[1/10] Установка зависимостей..."
export DEBIAN_FRONTEND=noninteractive
apt-get update > /dev/null
apt-get install -y postfix opendkim opendkim-tools mailutils certbot dovecot-core dovecot-imapd curl > /dev/null

# 2. Настройка hostname
echo "[2/10] Настройка hostname..."
hostnamectl set-hostname "$HOSTNAME"
echo "$DOMAIN" > /etc/mailname

# 3. Конфигурация Postfix
echo "[3/10] Конфигурация Postfix..."
postconf -e "myhostname = $HOSTNAME"
postconf -e "myorigin = /etc/mailname"
postconf -e "inet_interfaces = all"
postconf -e "inet_protocols = all"
postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost"
postconf -e "home_mailbox = Maildir/"
postconf -e "smtpd_banner = \$myhostname ESMTP"
postconf -e "milter_default_action = accept"
postconf -e "milter_protocol = 2"
postconf -e "smtpd_milters = inet:localhost:12301"
postconf -e "non_smtpd_milters = inet:localhost:12301"
postconf -e "smtpd_tls_auth_only = yes"
postconf -e "smtpd_sasl_type = dovecot"
postconf -e "smtpd_sasl_path = private/auth"
postconf -e "smtpd_sasl_auth_enable = yes"

# 4. Настройка DKIM
echo "[4/10] Настройка DKIM..."
mkdir -p "/etc/opendkim/keys/$DOMAIN"
cat > /etc/opendkim.conf <<EOF
AutoRestart             Yes
AutoRestartRate         10/1h
Syslog                  yes
UMask                   002
Canonicalization        relaxed/simple
Mode                    sv
SubDomains              no
Socket                  inet:12301@localhost
PidFile                 /var/run/opendkim/opendkim.pid
UserID                  opendkim:opendkim

KeyTable                /etc/opendkim/key.table
SigningTable            /etc/opendkim/signing.table
ExternalIgnoreList      /etc/opendkim/trusted.hosts
InternalHosts           /etc/opendkim/trusted.hosts
EOF

cd "/etc/opendkim/keys/$DOMAIN"
opendkim-genkey -s "$DKIM_SELECTOR" -d "$DOMAIN"
chown opendkim:opendkim "$DKIM_SELECTOR.private"

cat > /etc/opendkim/key.table <<EOF
$DKIM_SELECTOR._domainkey.$DOMAIN $DOMAIN:$DKIM_SELECTOR:/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.private
EOF

cat > /etc/opendkim/signing.table <<EOF
*@$DOMAIN $DKIM_SELECTOR._domainkey.$DOMAIN
EOF

cat > /etc/opendkim/trusted.hosts <<EOF
127.0.0.1
localhost
$DOMAIN
*.${DOMAIN}
EOF

# 5. Получение SSL
echo "[5/10] Получение Let's Encrypt сертификата..."
if certbot certonly --standalone -d "$HOSTNAME" --agree-tos --email "admin@$DOMAIN" --non-interactive > /dev/null 2>&1; then
    echo "[+] SSL успешно установлен"
    postconf -e "smtpd_tls_cert_file = /etc/letsencrypt/live/$HOSTNAME/fullchain.pem"
    postconf -e "smtpd_tls_key_file = /etc/letsencrypt/live/$HOSTNAME/privkey.pem"
    postconf -e "smtpd_use_tls = yes"
else
    echo "[-] Не удалось получить SSL. Продолжаем без TLS"
fi

# 6. Создание пользователя
echo "[6/10] Создание пользователя $USERNAME..."
if id "$USERNAME" &>/dev/null; then
    echo "[!] Пользователь $USERNAME уже существует"
else
    useradd -m -s /bin/bash "$USERNAME"
fi
echo "$USERNAME:$PASSWORD" | chpasswd
mkdir -p "/home/$USERNAME/Maildir"
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/Maildir"

# 7. Настройка Dovecot
echo "[7/10] Настройка Dovecot..."
cat > /etc/dovecot/conf.d/10-master.conf <<EOF
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
EOF

# 8. Перезапуск сервисов
echo "[8/10] Перезапуск сервисов..."
usermod -aG opendkim postfix
systemctl enable opendkim postfix dovecot > /dev/null
systemctl restart opendkim postfix dovecot

# 9. Автопродление сертификатов
echo "[9/10] Настройка автопродления сертификатов..."
echo "0 3 * * * root certbot renew --quiet && systemctl reload postfix" > /etc/cron.d/certbot_postfix

# 10. Получение внешнего IP
EXTERNAL_IP=$(curl -s https://ifconfig.me)

# --- Вывод информации ---
echo "[10/10] Настройка завершена!"
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║           SMTP КОНФИГУРАЦИЯ             ║"
echo "╠══════════════════════════════════════════╣"
echo "║  Домен:          $DOMAIN"
echo "║  Хост:           $HOSTNAME"
echo "║  Пользователь:   $USERNAME"
echo "║  Пароль:         $PASSWORD"
echo "║  SMTP Порт:      587 (STARTTLS)"
echo "║  DKIM Селектор:  $DKIM_SELECTOR"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "DNS записи для настройки:"
echo "1. A-запись: mail.$DOMAIN → $EXTERNAL_IP"
echo "2. MX-запись: @ → mail.$DOMAIN (приоритет 10)"
echo "3. SPF:"
echo "   @ TXT \"v=spf1 mx a ip4:$EXTERNAL_IP ~all\""
echo "4. DKIM:"
cat "/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.txt"
echo "5. DMARC:"
echo "   _dmarc TXT \"v=DMARC1; p=none; rua=mailto:dmarc@$DOMAIN\""
echo ""
echo "Для теста отправки:"
echo "swaks --to test@$DOMAIN --from test@$DOMAIN --server $HOSTNAME --auth LOGIN --auth-user $USERNAME --auth-password '$PASSWORD' --tls"
echo ""
echo "⚠️ Не забудьте настроить DNS записи и открыть порты в брандмауэре!"
tput cnorm  # возвращаем курсор

# Сохранение конфигурации в файл
CONFIG_FILE="/root/smtp_config_$DOMAIN.txt"
{
    echo "Домен: $DOMAIN"
    echo "Хост: $HOSTNAME"
    echo "Пользователь: $USERNAME"
    echo "Пароль: $PASSWORD"
    echo "DKIM Селектор: $DKIM_SELECTOR"
    echo "DKIM Запись:"
    cat "/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.txt"
} > "$CONFIG_FILE"

echo "[+] Конфигурация сохранена в $CONFIG_FILE"