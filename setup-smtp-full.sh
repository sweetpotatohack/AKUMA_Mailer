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

echo "[*] Начинаем развертывание SMTP-сервера для домена: $DOMAIN"

echo "[1/13] Установка зависимостей..."
export DEBIAN_FRONTEND=noninteractive
apt-get update > /dev/null
apt-get install -y postfix opendkim opendkim-tools mailutils certbot dovecot-core dovecot-imapd dovecot-sieve dovecot-managesieved curl ufw snapd > /dev/null

echo "[2/13] Настройка hostname..."
hostnamectl set-hostname "$HOSTNAME"
echo "$DOMAIN" > /etc/mailname

echo "[3/13] Конфигурация Postfix..."
postconf -e "myhostname = $HOSTNAME"
postconf -e "myorigin = /etc/mailname"
postconf -e "inet_interfaces = all"
postconf -e "inet_protocols = ipv4"
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
postconf -e "smtpd_tls_security_level = encrypt"
postconf -e "smtpd_tls_mandatory_protocols = !SSLv2,!SSLv3,!TLSv1,!TLSv1.1"
postconf -e "smtpd_tls_protocols = !SSLv2,!SSLv3,!TLSv1,!TLSv1.1"

# Настройка портов 465 и 587 в master.cf
cat >> /etc/postfix/master.cf <<EOF
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_tls_auth_only=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o smtpd_recipient_restrictions=permit_mynetworks,permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING

smtps     inet  n       -       y       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o smtpd_recipient_restrictions=permit_mynetworks,permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
EOF

echo "[4/13] Настройка DKIM..."
mkdir -p "/etc/opendkim/keys/$DOMAIN"
opendkim-genkey -s "$DKIM_SELECTOR" -d "$DOMAIN" -D "/etc/opendkim/keys/$DOMAIN"
chown opendkim:opendkim "/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.private"

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

DKIM_RECORD=$(cat "/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.txt")

echo "[5/13] Настройка SSL/TLS..."
mkdir -p /etc/ssl/private
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "/etc/ssl/private/$HOSTNAME.key" \
  -out "/etc/ssl/certs/$HOSTNAME.crt" \
  -subj "/CN=$HOSTNAME" > /dev/null 2>&1

postconf -e "smtpd_tls_cert_file = /etc/ssl/certs/$HOSTNAME.crt"
postconf -e "smtpd_tls_key_file = /etc/ssl/private/$HOSTNAME.key"
postconf -e "smtpd_use_tls = yes"

echo "[6/13] Создание пользователя $USERNAME..."
useradd -m -s /bin/bash "$USERNAME" 2>/dev/null || true
echo "$USERNAME:$PASSWORD" | chpasswd
mkdir -p "/home/$USERNAME/Maildir"
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/Maildir"

echo "[7/13] Настройка Dovecot..."
mkdir -p /var/spool/postfix/private
chown postfix:postfix /var/spool/postfix/private
chmod 750 /var/spool/postfix/private

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

echo "[9/13] Настройка firewall (ufw)..."
ufw allow 25/tcp
ufw allow 587/tcp
ufw allow 465/tcp
ufw allow 993/tcp
ufw --force enable > /dev/null 2>&1

echo "[10/13] Получение внешнего IP..."
EXTERNAL_IP=$(curl -4 -s https://ifconfig.me)
PTR_RECORD=$(dig +short -x "$EXTERNAL_IP" 2>/dev/null || echo "Не найдена")

echo "[11/13] Создание конфигурационного файла..."
CONFIG_FILE="/root/smtp_config_$DOMAIN.txt"
cat > "$CONFIG_FILE" <<EOF
╔══════════════════════════════════════════╗
║           SMTP КОНФИГУРАЦИЯ              ║
╠══════════════════════════════════════════╣
║  Домен:          $DOMAIN
║  Хост:           $HOSTNAME
║  Пользователь:   $USERNAME
║  Пароль:         $PASSWORD
║  Внешний IP:     $EXTERNAL_IP
║  PTR запись:     $PTR_RECORD
╚══════════════════════════════════════════╝

DNS записи:
1. A-запись: mail.$DOMAIN → $EXTERNAL_IP
2. MX-запись: @ → mail.$DOMAIN (приоритет 10)
3. SPF: @ TXT "v=spf1 ip4:$EXTERNAL_IP -all"
4. DKIM: $(cat "/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.txt")
5. DMARC: _dmarc TXT "v=DMARC1; p=none; rua=mailto:dmarc@$DOMAIN"

Тест отправки:
# Через порт 587 (STARTTLS):
swaks --to test@example.com --from $USERNAME@$DOMAIN \\
      --server $HOSTNAME --port 587 \\
      --auth LOGIN --auth-user $USERNAME \\
      --auth-password '$PASSWORD' --tls

# Через порт 465 (SSL/TLS):
swaks --to test@example.com --from $USERNAME@$DOMAIN \\
      --server $HOSTNAME --port 465 \\
      --auth LOGIN --auth-user $USERNAME \\
      --auth-password '$PASSWORD' --tlsc
EOF

echo -e "\n\e[1;32m[✔] Установка завершена успешно!\e[0m"
echo -e "\e[1;33mКонфигурация сохранена в: $CONFIG_FILE\e[0m"
