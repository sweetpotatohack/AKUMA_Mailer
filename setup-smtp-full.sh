#!/bin/bash
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
    echo -ne "\e[1;38;5;82m$line\e[0m\n"
  fi
  sleep 0.2
done

# ASCII-заставка с ником AKUMA
echo -e "\n\e[1;38;5;201m █████╗ ██╗  ██╗██╗   ██╗███╗   ███╗ █████╗ \n██╔══██╗██║ ██╔╝██║   ██║████╗ ████║██╔══██╗\n███████║█████╔╝ ██║   ██║██╔████╔██║███████║\n██╔══██║██╔═██╗ ██║   ██║██║╚██╔╝██║██╔══██║\n██║  ██║██║  ██╗╚██████╔╝██║ ╚═╝ ██║██║  ██║\n╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝\n\e[0m"

echo ""
echo -ne "\e[1;38;5;93m┌──────────────────────────────────────────────────────┐\e[0m\n"
echo -ne "\e[1;38;5;93m│ \e[0m\e[1;38;5;87m   HACK MODULE LOADED :: WELCOME, OPERATIVE   \e[0m\e[1;38;5;93m│\e[0m\n"
echo -ne "\e[1;38;5;93m└──────────────────────────────────────────────────────┘\e[0m\n"
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
tput cnorm  # вернуть курсор

set +H
set -e

# --- Конфигурация по умолчанию ---
DEFAULT_DOMAIN="example.com"
DEFAULT_USER="smtp_user"
DKIM_SELECTOR="mail"
SMTP_PORT=587
SMTPS_PORT=465

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

# Установка зависимостей
export DEBIAN_FRONTEND=noninteractive
apt-get update > /dev/null
apt-get install -y postfix opendkim opendkim-tools mailutils certbot dovecot-core dovecot-imapd dovecot-sieve dovecot-managesieved curl ufw snapd > /dev/null

hostnamectl set-hostname "$HOSTNAME"
echo "$DOMAIN" > /etc/mailname

# Настройка Postfix
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
postconf -e "smtpd_use_tls = yes"

# Правка master.cf для стандартных портов
sed -i "/^submission /,/^$/d" /etc/postfix/master.cf
sed -i "/^smtps /,/^$/d" /etc/postfix/master.cf

cat >> /etc/postfix/master.cf <<EOF
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_tls_auth_only=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING

smtps     inet  n       -       y       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
EOF

# DKIM
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

# SSL
mkdir -p /etc/ssl/private
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "/etc/ssl/private/$HOSTNAME.key" \
  -out "/etc/ssl/certs/$HOSTNAME.crt" \
  -subj "/CN=$HOSTNAME" > /dev/null 2>&1

postconf -e "smtpd_tls_cert_file = /etc/ssl/certs/$HOSTNAME.crt"
postconf -e "smtpd_tls_key_file = /etc/ssl/private/$HOSTNAME.key"

# Пользователь
useradd -m -s /bin/bash "$USERNAME" 2>/dev/null || true
echo "$USERNAME:$PASSWORD" | chpasswd
mkdir -p "/home/$USERNAME/Maildir"
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/Maildir"

# Dovecot
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

usermod -aG opendkim postfix
systemctl enable opendkim postfix dovecot > /dev/null
systemctl restart opendkim postfix dovecot

# Firewall
ufw allow 25/tcp
ufw allow 587/tcp
ufw allow 465/tcp
ufw allow 993/tcp
ufw --force enable > /dev/null 2>&1

EXTERNAL_IP=$(curl -4 -s https://ifconfig.me)
PTR_RECORD=$(dig +short -x "$EXTERNAL_IP" 2>/dev/null || echo "Не найдена")

CONFIG_FILE="/root/smtp_config_$DOMAIN.txt"
cat > "$CONFIG_FILE" <<EOF
SMTP Конфигурация:
Домен:          $DOMAIN
Хост:           $HOSTNAME
Пользователь:   $USERNAME
Пароль:         $PASSWORD
Внешний IP:     $EXTERNAL_IP
PTR:            $PTR_RECORD
SMTP порт:      587
SMTPS порт:     465

DNS:
A: mail.$DOMAIN -> $EXTERNAL_IP
MX: @ -> mail.$DOMAIN (10)
SPF: "v=spf1 ip4:$EXTERNAL_IP -all"
DKIM: $(cat "/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.txt")
DMARC: "v=DMARC1; p=none; rua=mailto:dmarc@$DOMAIN"

Примеры:
swaks --to test@example.com --from $USERNAME@$DOMAIN --server $HOSTNAME \
  --port 587 --auth LOGIN --auth-user $USERNAME --auth-password '$PASSWORD' --tls
EOF

echo -e "\n[✔] SMTP сервер установлен. Конфигурация: $CONFIG_FILE"
tput cnorm
