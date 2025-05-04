#!/bin/bash

set +H
set -e

# --- Конфигурация по умолчанию ---
DEFAULT_DOMAIN="example.com"
DEFAULT_USER="smtp_user"
DKIM_SELECTOR="mail"

# --- Проверка прав ---
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт должен запускаться с правами root!" >&2
    exit 1
fi

# --- Аргументы командной строки ---
NO_LOG=0
while getopts "d:u:n" opt; do
    case $opt in
        d) DOMAIN="$OPTARG" ;;
        u) USERNAME="$OPTARG" ;;
        n) NO_LOG=1 ;;
        *) echo "Использование: $0 [-d domain] [-u username] [-n]" >&2
           exit 1 ;;
    esac
done

DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}
USERNAME=${USERNAME:-$DEFAULT_USER}
HOSTNAME="mail.$DOMAIN"
PASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9@#%&*_' | head -c 16)

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
"Ξ ███████████████████████▓▓▓▓▓░░░░░░░░ [76%] синхронизация с darknet"
"Ξ ████████████████████████████████████ [100%] ты больше не человек"
)

for line in "${glitch_lines[@]}"; do
  if command -v lolcat &>/dev/null; then
    echo -ne "\e[1;32m$line\e[0m\n" | lolcat
  else
    echo -ne "\e[1;32m$line\e[0m\n"
  fi
  sleep 0.25
done

echo ""
echo -ne "\e[1;35m┌──────────────────────────────────────────────────────┐\e[0m\n"
echo -ne "\e[1;35m│ \e[0m\e[1;36m   HACK MODULE LOADED :: WELCOME, OPERATIVE.   \e[0m\e[1;35m      │\e[0m\n"
echo -ne "\e[1;35m└──────────────────────────────────────────────────────┘\e[0m\n"
sleep 1

for i in {1..30}; do
    echo -ne "\e[32m$(head /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*_?' | head -c $((RANDOM % 28 + 12)))\r\e[0m"
    sleep 0.05
done

sleep 0.3

nickname="AKUMA"
for ((i=0; i<${#nickname}; i++)); do
    echo -ne "\e[1;31m${nickname:$i:1}\e[0m"
    sleep 0.2
done

echo -e "\n"
echo -e "\n💀 Все системы онлайн. Если что — это не мы."
echo -e "🧠 Добро пожаловать в матрицу, \e[1;32m$nickname\e[0m... У нас тут sudo и печеньки 🍪."
tput cnorm  # вернуть курсор
echo -e "\n"

echo "[*] Начинаем развертывание SMTP-сервера для домена: $DOMAIN"

echo "[1/13] Установка зависимостей..."
export DEBIAN_FRONTEND=noninteractive
apt-get update > /dev/null
apt-get install -y postfix opendkim opendkim-tools mailutils certbot dovecot-core dovecot-imapd curl ufw snapd > /dev/null

echo "[2/13] Настройка hostname..."
hostnamectl set-hostname "$HOSTNAME"
echo "$DOMAIN" > /etc/mailname

echo "[3/13] Конфигурация Postfix..."
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

echo "[4/13] Настройка DKIM..."
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

cat > /etc/opendkim/key.table <<EOF
$DKIM_SELECTOR._domainkey.$DOMAIN $DOMAIN:$DKIM_SELECTOR:/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.private
EOF

cat > /etc/opendkim/signing.table <<EOF
*@${DOMAIN} $DKIM_SELECTOR._domainkey.${DOMAIN}
EOF

cat > /etc/opendkim/trusted.hosts <<EOF
127.0.0.1
localhost
$DOMAIN
*.${DOMAIN}
EOF

cd "/etc/opendkim/keys/$DOMAIN"
opendkim-genkey -s "$DKIM_SELECTOR" -d "$DOMAIN"
chown opendkim:opendkim "$DKIM_SELECTOR.private"

DKIM_RECORD=$(cat "/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.txt")

echo "[5/13] Получение Let's Encrypt сертификата..."
if certbot certonly --standalone -d "$HOSTNAME" --agree-tos --email "admin@$DOMAIN" --non-interactive > /dev/null 2>&1; then
    echo "[+] SSL успешно установлен"
    postconf -e "smtpd_tls_cert_file = /etc/letsencrypt/live/$HOSTNAME/fullchain.pem"
    postconf -e "smtpd_tls_key_file = /etc/letsencrypt/live/$HOSTNAME/privkey.pem"
    postconf -e "smtpd_use_tls = yes"
else
    echo "[-] Не удалось получить SSL. Продолжаем без TLS"
fi

echo "[6/13] Создание пользователя $USERNAME..."
if id "$USERNAME" &>/dev/null; then
    echo "[!] Пользователь $USERNAME уже существует"
else
    useradd -m -s /bin/bash "$USERNAME"
fi
echo "$USERNAME:$PASSWORD" | chpasswd
mkdir -p "/home/$USERNAME/Maildir"
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/Maildir"

echo "[7/13] Настройка Dovecot..."
cat > /etc/dovecot/conf.d/10-master.conf <<EOF
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
EOF

echo "mail_location = maildir:~/Maildir" >> /etc/dovecot/conf.d/10-mail.conf
echo "disable_plaintext_auth = no" >> /etc/dovecot/conf.d/10-auth.conf
echo "auth_mechanisms = plain login" >> /etc/dovecot/conf.d/10-auth.conf

echo "[8/13] Перезапуск сервисов..."
usermod -aG opendkim postfix
systemctl enable opendkim postfix dovecot > /dev/null
systemctl restart opendkim postfix dovecot

echo "[9/13] Настройка автопродления сертификатов..."
snap install core; snap refresh core
snap install certbot --classic
ln -sf /snap/bin/certbot /usr/bin/certbot
echo "0 3 * * 1 root certbot renew --post-hook 'systemctl reload postfix dovecot'" > /etc/cron.d/certbot-renew

echo "[10/13] Настройка firewall (ufw)..."
ufw allow 25
ufw allow 587
ufw allow 993
ufw --force enable

echo "[11/13] Проверка конфигурации..."
postfix check
dovecot -n

echo "[12/13] Получение внешнего IP..."
EXTERNAL_IP=$(curl -s https://ifconfig.me)

echo "[13/13] Завершено!"
CONFIG_FILE="/root/smtp_config_$DOMAIN.txt"
cat > "$CONFIG_FILE" <<EOF

╔══════════════════════════════════════════╗
║           SMTP КОНФИГУРАЦИЯ              ║
╠══════════════════════════════════════════╣
║  Домен:          $DOMAIN
║  Хост:           $HOSTNAME
║  Пользователь:   $USERNAME
║  Пароль:         $PASSWORD
║  SMTP Порт:      587 (STARTTLS)
║  DKIM Селектор:  $DKIM_SELECTOR
╚══════════════════════════════════════════╝

DNS записи для настройки:
1. A-запись: mail.$DOMAIN → $EXTERNAL_IP
2. MX-запись: @ → mail.$DOMAIN (приоритет 10)
3. SPF:
   @ TXT "v=spf1 ip4:$EXTERNAL_IP -all"
4. DKIM:
   $DKIM_SELECTOR._domainkey.$DOMAIN TXT "$(echo "$DKIM_RECORD" | grep -oP '".*"' | sed 's/"//g')"
5. DMARC:
   _dmarc TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@$DOMAIN"

⚠️ Не забудьте настроить PTR-запись для IP!

EOF

echo -e "\n[+] DKIM ключ:\n"
echo "$DKIM_RECORD"

echo -e "\n\e[1;35m┌────────────────────────────────────────────────────────────┐\e[0m"
echo -e "\e[1;35m│\e[0m \e[1;36m    SMTP СЕРВЕР ГОТОВ :: ИНФОРМАЦИЯ ДЛЯ ПОДКЛЮЧЕНИЯ     \e[0m\e[1;35m│\e[0m"
echo -e "\e[1;35m└────────────────────────────────────────────────────────────┘\e[0m"
sleep 0.5

IFS=$'\n'
for line in $(cat "$CONFIG_FILE"); do
    if command -v lolcat &>/dev/null; then
        echo -e "$line" | lolcat
    else
        echo -e "$line"
    fi
    sleep 0.08
done

echo -e "\n\e[1;32m[✔] Готово. Сервер в боевой готовности.\e[0m"
echo -e "\e[1;33m[ℹ] Файл конфигурации сохранён: \e[1;36m$CONFIG_FILE\e[0m"
echo -e "\e[1;35m[⚠] Не забудь обновить DNS-записи вручную!\e[0m\n"
