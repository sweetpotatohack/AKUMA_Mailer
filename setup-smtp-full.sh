#!/bin/bash
set -e
tput civis 2>/dev/null

# --- КИБЕРПАНК-СТАРТ ---
glitch_lines=(
  "Ξ Разогрев SSL-реактора... [жду Let’s Encrypt]"
  "Ξ Проверка DNS, шаманю PTR..."
  "Ξ Калибрую DKIM [выше, сильнее, валиднее]"
  "Ξ Ставлю ловушку на спам-фильтры..."
  "Ξ ███████████████████████▓▓▓▓▓░░░░░░░░ [80%] Грею порт 587"
  "Ξ ████████████████████████████████████ [100%] Сервер готов, AKUMA!"
)
for line in "${glitch_lines[@]}"; do
  if command -v lolcat &>/dev/null; then
    echo -e "$line" | lolcat
  else
    echo -e "$line"
  fi
  sleep 0.18
done

echo -e "\n\033[1;38;5;201mSMTP Deploy v3 :: Let’s Encrypt Edition :: for AKUMA\033[0m\n"
sleep 0.2

# --- Конфиг ---
DEFAULT_DOMAIN="example.com"
DEFAULT_USER="akuma"
DKIM_SELECTOR="mail"
SMTP_PORT=587
SMTPS_PORT=465

if [[ $EUID -ne 0 ]]; then
  echo "Run as root, mortal!" && exit 77
fi

while getopts "d:u:" opt; do
  case $opt in
    d) DOMAIN="$OPTARG" ;;
    u) USERNAME="$OPTARG" ;;
    *) echo "Usage: $0 [-d domain] [-u username]" && exit 1 ;;
  esac
done

DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}
USERNAME=${USERNAME:-$DEFAULT_USER}
HOSTNAME="mail.$DOMAIN"
PASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9@#%&*_' | head -c 16)

export DEBIAN_FRONTEND=noninteractive

# --- Установка пакетов ---
apt-get update -qq
apt-get install -y postfix dovecot-core dovecot-imapd opendkim opendkim-tools mailutils curl ufw certbot dnsutils

hostnamectl set-hostname "$HOSTNAME"
echo "$DOMAIN" > /etc/mailname

# --- Проверка A-записи (ожидание появления DNS) ---
echo "[*] Проверяю наличие A-записи для $HOSTNAME..."
EXT_IP=$(curl -4 -s https://ifconfig.me)
TRIES=0
while [[ "$(dig +short $HOSTNAME | grep -w $EXT_IP || true)" == "" ]]; do
  ((TRIES++))
  if [[ $TRIES -gt 25 ]]; then
    echo "A-запись на $HOSTNAME не указывает на этот сервер ($EXT_IP). Проверь DNS или жди обновления зоны!"
    exit 2
  fi
  echo "Ожидание появления A-записи $HOSTNAME -> $EXT_IP (попытка $TRIES/25)..."
  sleep 8
done
echo "[+] A-запись на месте!"

# --- Получаем Let's Encrypt SSL ---
ufw allow 80/tcp
systemctl stop postfix dovecot 2>/dev/null || true
certbot certonly --standalone --preferred-challenges http -d $HOSTNAME --register-unsafely-without-email --agree-tos --noninteractive
systemctl start postfix dovecot

# --- POSTFIX ---
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
postconf -e "smtpd_tls_security_level = may"
postconf -e "smtpd_tls_protocols = !SSLv2,!SSLv3,!TLSv1,!TLSv1.1"
postconf -e "smtpd_use_tls = yes"
postconf -e "smtpd_tls_cert_file = /etc/letsencrypt/live/$HOSTNAME/fullchain.pem"
postconf -e "smtpd_tls_key_file = /etc/letsencrypt/live/$HOSTNAME/privkey.pem"

# --- master.cf submission/smtps ---
if ! grep -q "submission inet" /etc/postfix/master.cf; then
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
fi

# --- DKIM ---
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

# --- User для GoPhish ---
useradd -m -s /bin/bash "$USERNAME" 2>/dev/null || true
echo "$USERNAME:$PASSWORD" | chpasswd
mkdir -p "/home/$USERNAME/Maildir"
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/Maildir"

# --- Dovecot + SSL ---
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

cat > /etc/dovecot/conf.d/10-ssl.conf <<EOF
ssl = required
ssl_cert = </etc/letsencrypt/live/$HOSTNAME/fullchain.pem
ssl_key = </etc/letsencrypt/live/$HOSTNAME/privkey.pem
EOF

usermod -aG opendkim postfix
systemctl enable opendkim postfix dovecot
systemctl restart opendkim postfix dovecot

# --- Firewall ---
ufw allow 25/tcp
ufw allow 587/tcp
ufw allow 465/tcp
ufw allow 993/tcp
ufw --force enable

PTR_RECORD=$(dig +short -x "$EXT_IP" 2>/dev/null || echo "Не найдена")
CONFIG_FILE="/root/smtp_config_$DOMAIN.txt"
cat > "$CONFIG_FILE" <<EOF
SMTP Конфигурация:
Домен:          $DOMAIN
Хост:           $HOSTNAME
Пользователь:   $USERNAME
Пароль:         $PASSWORD
Внешний IP:     $EXT_IP
PTR:            $PTR_RECORD
SMTP порт:      587
SMTPS порт:     465

DNS:
A: mail.$DOMAIN -> $EXT_IP
MX: @ -> mail.$DOMAIN (10)
SPF: "v=spf1 ip4:$EXT_IP -all"
DKIM: $(cat "/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.txt")
DMARC: "v=DMARC1; p=none; rua=mailto:dmarc@$DOMAIN"

Пример теста:
swaks --to test@example.com --from $USERNAME@$DOMAIN --server $HOSTNAME \
  --port 587 --auth LOGIN --auth-user $USERNAME --auth-password '$PASSWORD' --tls
EOF

echo -e "\n[✔] SMTP сервер для рассылки готов!\n[!] Все настройки в: $CONFIG_FILE"
echo -e "\n[!] Не забудь:\n • Прописать DNS (A/MX/SPF/DKIM/DMARC)\n • Проверить PTR на IP ($EXT_IP)\n"
tput cnorm 2>/dev/null
