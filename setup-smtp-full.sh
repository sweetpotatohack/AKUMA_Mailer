#!/bin/bash
set -e
tput civis 2>/dev/null

# --- КИБЕРПАНК-СТАРТ ---
glitch_lines=(
  "Ξ Разогрев SSL-реактора... [жду Let's Encrypt]"
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

echo -e "\n\033[1;38;5;201mSMTP Deploy v4 :: Full Auto Edition :: for AKUMA\033[0m\n"
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
echo "[*] Устанавливаю пакеты..."
apt-get update -qq
apt-get install -y postfix dovecot-core dovecot-imapd opendkim opendkim-tools \
  mailutils curl ufw certbot dnsutils swaks lolcat

hostnamectl set-hostname "$HOSTNAME"
echo "$DOMAIN" > /etc/mailname

# --- Проверка DNS ---
echo "[*] Проверяю DNS записи..."
EXT_IP=$(curl -4 -s https://ifconfig.me)
TRIES=0
while [[ "$(dig +short $HOSTNAME | grep -w $EXT_IP || true)" == "" ]]; do
  ((TRIES++))
  if [[ $TRIES -gt 25 ]]; then
    echo "[!] A-запись $HOSTNAME не указывает на $EXT_IP. Проверь DNS!"
    exit 2
  fi
  echo "Ожидание DNS (попытка $TRIES/25)..."
  sleep 8
done
echo "[+] DNS проверка пройдена!"

# --- Получаем SSL ---
echo "[*] Получаю SSL сертификат..."
ufw allow 80/tcp
systemctl stop postfix dovecot 2>/dev/null || true
certbot certonly --standalone --preferred-challenges http -d $HOSTNAME \
  --register-unsafely-without-email --agree-tos --noninteractive
systemctl start postfix dovecot

# --- Postfix main.cf ---
echo "[*] Настраиваю Postfix..."
cat > /etc/postfix/main.cf <<EOF
# Основные настройки
smtpd_banner = \$myhostname ESMTP
biff = no
append_dot_mydomain = no
readme_directory = no
compatibility_level = 3.6

# TLS настройки
smtpd_tls_cert_file = /etc/letsencrypt/live/$HOSTNAME/fullchain.pem
smtpd_tls_key_file = /etc/letsencrypt/live/$HOSTNAME/privkey.pem
smtpd_tls_security_level = may
smtpd_tls_auth_only = yes
smtpd_tls_protocols = !SSLv2,!SSLv3,!TLSv1,!TLSv1.1
smtpd_tls_mandatory_protocols = !SSLv2,!SSLv3,!TLSv1,!TLSv1.1
smtpd_tls_exclude_ciphers = aNULL, LOW, EXP, MEDIUM, ADH, AECDH, MD5, DSS, ECDSA
smtpd_use_tls = yes

# SASL аутентификация
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
broken_sasl_auth_clients = yes

# Настройки релея
smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, defer_unauth_destination

# Сетевые настройки
myhostname = $HOSTNAME
mydestination = \$myhostname, $HOSTNAME, $DOMAIN, localhost.\$mydomain, localhost
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
inet_interfaces = all
inet_protocols = ipv4

# Настройки почты
home_mailbox = Maildir/
mailbox_size_limit = 0
recipient_delimiter = +
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
myorigin = /etc/mailname

# DKIM
milter_default_action = accept
milter_protocol = 2
smtpd_milters = inet:localhost:12301
non_smtpd_milters = inet:localhost:12301
EOF

# --- Postfix master.cf ---
echo "[*] Настраиваю порты 587/465..."
cat > /etc/postfix/master.cf <<EOF
# ==========================================================================
# service type  private unpriv  chroot  wakeup  maxproc command + args
#               (yes)   (yes)   (no)    (never) (100)
# ==========================================================================
smtp      inet  n       -       y       -       -       smtpd

submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING

smtps     inet  n       -       y       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING

pickup    unix  n       -       y       60      1       pickup
cleanup   unix  n       -       y       -       0       cleanup
qmgr      unix  n       -       n       300     1       qmgr
tlsmgr    unix  -       -       y       1000?   1       tlsmgr
rewrite   unix  -       -       y       -       -       trivial-rewrite
bounce    unix  -       -       y       -       0       bounce
defer     unix  -       -       y       -       0       bounce
trace     unix  -       -       y       -       0       bounce
verify    unix  -       -       y       -       1       verify
flush     unix  n       -       y       1000?   0       flush
proxymap  unix  -       -       n       -       -       proxymap
proxywrite unix -       -       n       -       1       proxymap
smtp      unix  -       -       y       -       -       smtp
relay     unix  -       -       y       -       -       smtp
showq     unix  n       -       y       -       -       showq
error     unix  -       -       y       -       -       error
retry     unix  -       -       y       -       -       error
discard   unix  -       -       y       -       -       discard
local     unix  -       n       n       -       -       local
virtual   unix  -       n       n       -       -       virtual
lmtp      unix  -       -       y       -       -       lmtp
anvil     unix  -       -       y       -       1       anvil
scache    unix  -       -       y       -       1       scache
EOF

# --- DKIM ---
echo "[*] Настраиваю DKIM..."
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

# --- Dovecot ---
echo "[*] Настраиваю Dovecot..."
cat > /etc/dovecot/conf.d/10-master.conf <<EOF
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
EOF

echo "mail_location = maildir:~/Maildir" > /etc/dovecot/conf.d/10-mail.conf
echo "disable_plaintext_auth = no" > /etc/dovecot/conf.d/10-auth.conf
echo "auth_mechanisms = plain login" >> /etc/dovecot/conf.d/10-auth.conf

cat > /etc/dovecot/conf.d/10-ssl.conf <<EOF
ssl = required
ssl_cert = </etc/letsencrypt/live/$HOSTNAME/fullchain.pem
ssl_key = </etc/letsencrypt/live/$HOSTNAME/privkey.pem
ssl_min_protocol = TLSv1.2
ssl_prefer_server_ciphers = yes
ssl_cipher_list = EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH
EOF

# --- Создаем пользователя ---
echo "[*] Создаю пользователя $USERNAME..."
useradd -m -s /bin/bash "$USERNAME" 2>/dev/null || true
echo "$USERNAME:$PASSWORD" | chpasswd
mkdir -p "/home/$USERNAME/Maildir"
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/Maildir"

# --- Firewall ---
echo "[*] Настраиваю фаервол..."
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 22/tcp
ufw allow 25/tcp
ufw allow 587/tcp
ufw allow 465/tcp
ufw allow 993/tcp
ufw --force enable

# --- Запуск сервисов ---
echo "[*] Запускаю сервисы..."
usermod -aG opendkim postfix
systemctl enable opendkim postfix dovecot
systemctl restart opendkim postfix dovecot

# --- Проверка работы ---
echo "[*] Проверяю работу сервисов..."
if ! systemctl is-active --quiet postfix; then
  echo "[!] Ошибка: Postfix не запущен!"
  journalctl -u postfix -n 10 --no-pager
  exit 3
fi

if ! systemctl is-active --quiet dovecot; then
  echo "[!] Ошибка: Dovecot не запущен!"
  journalctl -u dovecot -n 10 --no-pager
  exit 4
fi

# --- Генерация отчета ---
PTR_RECORD=$(dig +short -x "$EXT_IP" 2>/dev/null || echo "Не найдена")
CONFIG_FILE="/root/smtp_config_$DOMAIN.txt"
cat > "$CONFIG_FILE" <<EOF
=== SMTP Конфигурация ===
Домен:          $DOMAIN
Хост:           $HOSTNAME
Пользователь:   $USERNAME
Пароль:         $PASSWORD
Внешний IP:     $EXT_IP
PTR:            $PTR_RECORD

=== Порты ===
SMTP:           25
Submission:     587 (TLS)
SMTPS:          465 (SSL)
IMAPS:          993

=== DNS записи ===
A:      mail.$DOMAIN -> $EXT_IP
MX:     @ 10 mail.$DOMAIN
TXT:    "v=spf1 ip4:$EXT_IP -all"
TXT:    $(cat "/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.txt")
TXT:    "v=DMARC1; p=none; rua=mailto:dmarc@$DOMAIN"

=== Тест отправки ===
swaks --to test@example.com --from $USERNAME@$DOMAIN --server $HOSTNAME \\
  --port 587 --auth LOGIN --auth-user $USERNAME --auth-password '$PASSWORD' --tls

=== Проверка TLS ===
openssl s_client -connect $HOSTNAME:587 -starttls smtp
EOF

echo -e "\n[✔] SMTP сервер полностью настроен!"
echo -e "[!] Все параметры сохранены в: \033[1;32m$CONFIG_FILE\033[0m"
echo -e "\n\033[1;33m[!] Не забудь добавить DNS записи:\033[0m"
echo "  • A запись: mail.$DOMAIN -> $EXT_IP"
echo "  • MX запись: @ -> mail.$DOMAIN (приоритет 10)"
echo "  • SPF: \"v=spf1 ip4:$EXT_IP -all\""
echo "  • DKIM: $(cat "/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.txt" | tr -d '\n')"
echo "  • DMARC: \"v=DMARC1; p=none; rua=mailto:dmarc@$DOMAIN\""
echo -e "\n\033[1;32m[+] Проверь работу командами:\033[0m"
echo "  swaks --to test@example.com --from $USERNAME@$DOMAIN --server $HOSTNAME \\"
echo "    --port 587 --auth LOGIN --auth-user $USERNAME --auth-password '$PASSWORD' --tls"
echo "  telnet $HOSTNAME 25"
echo "  openssl s_client -connect $HOSTNAME:587 -starttls smtp"

tput cnorm 2>/dev/null
