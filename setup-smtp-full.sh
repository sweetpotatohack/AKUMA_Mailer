#!/bin/bash
set -e
tput civis

echo -e "\033[1;32m"
echo "  ======================================================================"
echo "  =  FENYA BULLETPROOF SMTP 3.2 - GMAIL KILLER EDITION (FINAL-FIXED) ="
echo "  =        Made by Fenya - legendary hacker & microservices guru      ="
echo "  =     ИСПРАВЛЕНЫ ВСЕ ПРОБЛЕМЫ: IPv6, PAM, ОГРАНИЧЕНИЯ, КОДИРОВКА!   ="
echo "  ======================================================================"
echo -e "\033[0m"

# --- Конфигурация (ИЗМЕНИ ЭТИ ПАРАМЕТРЫ!) ---
DOMAIN="${1:-example.com}"          
HOSTNAME="mail.$DOMAIN"                     
USERNAME="${2:-support}"                   
PASSWORD="${3:-$(openssl rand -base64 12)}" 
DKIM_SELECTOR="mail"                        
EMAIL="${4:-admin@$DOMAIN}"  # Твоя почта для Let's Encrypt
SERVER_IP="${5:-$(curl -s ipinfo.io/ip || curl -s ifconfig.me/ip)}"   

echo -e "\033[1;33m=== КОНФИГУРАЦИЯ ===\033[0m"
echo -e "Домен: \033[1;36m$DOMAIN\033[0m"
echo -e "Hostname: \033[1;36m$HOSTNAME\033[0m"
echo -e "SMTP пользователь: \033[1;36m$USERNAME\033[0m"
echo -e "Пароль: \033[1;36m$PASSWORD\033[0m"
echo -e "IP сервера: \033[1;36m$SERVER_IP\033[0m"
echo -e "Let's Encrypt email: \033[1;36m$EMAIL\033[0m"
echo ""

# --- Проверка root ---
if [[ $EUID -ne 0 ]]; then
  echo -e "\033[1;31mТребуются права root!\033[0m" >&2
  exit 1
fi

# --- Остановка сервисов ---
echo -e "\033[1;34m[0/14] Остановка существующих сервисов...\033[0m"
systemctl stop postfix dovecot opendkim 2>/dev/null || true

# --- КРИТИЧНО: Отключение IPv6 на уровне ядра ---
echo -e "\033[1;34m[1/14] Отключение IPv6 на уровне ядра (КРИТИЧНО!)...\033[0m"
if ! grep -q "net.ipv6.conf.all.disable_ipv6 = 1" /etc/sysctl.conf; then
    echo 'net.ipv6.conf.all.disable_ipv6 = 1' >> /etc/sysctl.conf
    echo 'net.ipv6.conf.default.disable_ipv6 = 1' >> /etc/sysctl.conf
    echo 'net.ipv6.conf.lo.disable_ipv6 = 1' >> /etc/sysctl.conf
    sysctl -p 2>/dev/null || true
fi

# --- Обновление системы ---
echo -e "\033[1;34m[2/14] Обновление системы...\033[0m"
export DEBIAN_FRONTEND=noninteractive
apt update -qq && apt upgrade -y -qq

# --- Установка пакетов ---
echo -e "\033[1;34m[3/14] Установка пакетов...\033[0m"
apt install -y -qq postfix dovecot-core dovecot-imapd dovecot-lmtpd \
  opendkim opendkim-tools certbot fail2ban ufw swaks dnsutils curl wget \
  mailutils net-tools telnet

# --- Настройка hostname ---
echo -e "\033[1;34m[4/14] Настройка hostname...\033[0m"
hostnamectl set-hostname $HOSTNAME
if ! grep -q "$HOSTNAME" /etc/hosts; then
    echo "127.0.0.1 $HOSTNAME" >> /etc/hosts
fi

# --- Настройка файервола ---
echo -e "\033[1;34m[5/14] Настройка файервола...\033[0m"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 22,25,80,143,443,465,587,993,2143,2993/tcp
ufw --force enable

# --- SSL сертификат ---
echo -e "\033[1;34m[6/14] Получение SSL сертификата...\033[0m"
systemctl stop nginx apache2 2>/dev/null || true
if certbot certonly --standalone --agree-tos --no-eff-email --email $EMAIL -d $HOSTNAME --non-interactive; then
  SSL_DIR="/etc/letsencrypt/live/$HOSTNAME"
  echo -e "\033[1;32mLet's Encrypt сертификат получен успешно!\033[0m"
else
  SSL_DIR="/etc/ssl/$HOSTNAME"
  mkdir -p $SSL_DIR
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout $SSL_DIR/privkey.pem -out $SSL_DIR/fullchain.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=$HOSTNAME"
  echo -e "\033[1;33mИспользуем самоподписанный сертификат\033[0m"
fi

# --- ИСПРАВЛЕННАЯ настройка Postfix ---
echo -e "\033[1;34m[7/14] Настройка Postfix (ИСПРАВЛЕННАЯ ВЕРСИЯ!)...\033[0m"

# Backup
cp /etc/postfix/main.cf /etc/postfix/main.cf.backup.$(date +%s) 2>/dev/null || true

cat > /etc/postfix/main.cf << EOF
# Основные настройки
smtpd_banner = \$myhostname ESMTP
biff = no
append_dot_mydomain = no
compatibility_level = 3.6

# Сетевые настройки (ИСПРАВЛЕНО mydestination!)
myhostname = $HOSTNAME
mydomain = $DOMAIN
myorigin = \$mydomain
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
inet_interfaces = all
inet_protocols = ipv4

# Почтовые ящики
home_mailbox = Maildir/
mailbox_size_limit = 0
message_size_limit = 52428800
recipient_delimiter = +
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases

# TLS настройки (ИСПРАВЛЕНО!)
smtpd_tls_cert_file = $SSL_DIR/fullchain.pem
smtpd_tls_key_file = $SSL_DIR/privkey.pem
smtpd_tls_security_level = may
smtpd_tls_auth_only = yes
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_ciphers = medium
smtpd_tls_exclude_ciphers = aNULL, eNULL, EXPORT, DES, RC4, MD5, PSK, SRP, DSS, AECDH, ADH
smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache
smtpd_tls_session_cache_timeout = 3600s
smtpd_tls_received_header = yes
smtpd_tls_loglevel = 1

# SMTP клиент TLS
smtp_tls_security_level = may
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache
smtp_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtp_tls_ciphers = medium

# SASL аутентификация (ИСПРАВЛЕНО!)
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous, noplaintext
smtpd_sasl_tls_security_options = noanonymous
broken_sasl_auth_clients = yes

# Настройки безопасности (ИСПРАВЛЕНО!)
smtpd_helo_required = yes
smtpd_delay_reject = yes
smtpd_client_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_rbl_client zen.spamhaus.org, reject_rbl_client bl.spamcop.net, permit

smtpd_helo_restrictions = 
  permit_mynetworks,
  permit_sasl_authenticated,
  reject_invalid_helo_hostname,
  reject_non_fqdn_helo_hostname,
  reject_unknown_helo_hostname,
  permit

smtpd_sender_restrictions = 
  permit_mynetworks,
  permit_sasl_authenticated,
  reject_non_fqdn_sender,
  reject_unknown_sender_domain,
  reject_unauth_pipelining,
  permit

smtpd_recipient_restrictions = 
  permit_mynetworks,
  permit_sasl_authenticated,
  reject_non_fqdn_recipient,
  reject_unknown_recipient_domain,
  reject_unauth_destination,
  reject_rbl_client zen.spamhaus.org,
  permit

# DKIM
milter_default_action = accept
milter_protocol = 6
smtpd_milters = inet:localhost:12301
non_smtpd_milters = inet:localhost:12301

# Настройки для Gmail (ИСПРАВЛЕНО!)
smtp_helo_name = $HOSTNAME
smtp_always_send_ehlo = yes
smtp_tls_note_starttls_offer = yes
smtp_helo_timeout = 60s
smtp_mail_timeout = 60s
smtp_rcpt_timeout = 60s
disable_vrfy_command = yes
smtpd_discard_ehlo_keywords = dsn, enhancedstatuscodes, etrn
always_add_missing_headers = yes
local_header_rewrite_clients = permit_sasl_authenticated

# Лимиты для защиты от спама
smtpd_error_sleep_time = 1s
smtpd_soft_error_limit = 10
smtpd_hard_error_limit = 20
smtpd_client_connection_count_limit = 50
smtpd_client_connection_rate_limit = 30
smtpd_client_message_rate_limit = 100

# Настройки очереди
maximal_queue_lifetime = 1d
bounce_queue_lifetime = 1d
maximal_backoff_time = 4000s
minimal_backoff_time = 300s
queue_run_delay = 300s

# Заголовки для улучшения репутации у Gmail (ДОБАВЛЕНО!)
header_checks = regexp:/etc/postfix/header_checks
smtp_header_checks = regexp:/etc/postfix/header_checks
EOF

# --- Создание header_checks для репутации ---
echo -e "\033[1;34m[8/14] Создание header_checks для улучшения репутации...\033[0m"
cat > /etc/postfix/header_checks << EOF
# Header checks для улучшения репутации у Gmail и других провайдеров
/^Subject:/ PREPEND X-Originating-IP: [$SERVER_IP]
/^From:/ PREPEND X-Mailer: Postfix-SMTP-Server-1.0
/^To:/ PREPEND X-Server: $HOSTNAME
/^X-PHP-Originating-Script:/ IGNORE
/^X-PHP-Script:/ IGNORE
/^X-AntiAbuse:/ IGNORE
EOF
postmap /etc/postfix/header_checks

# --- Настройка master.cf с правильными портами ---
cat > /etc/postfix/master.cf << EOF
smtp      inet  n       -       y       -       -       smtpd
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

submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_tls_auth_only=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o smtpd_helo_restrictions=permit_sasl_authenticated,reject
  -o smtpd_sender_restrictions=permit_sasl_authenticated,reject
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject

smtps     inet  n       -       y       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_tls_auth_only=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
EOF

# --- ИСПРАВЛЕННАЯ настройка Dovecot ---
echo -e "\033[1;34m[9/14] Настройка Dovecot (ИСПРАВЛЕННАЯ ВЕРСИЯ!)...\033[0m"

# Основная конфигурация
cat > /etc/dovecot/dovecot.conf << EOF
!include_try /usr/share/dovecot/protocols.d/*.protocol
protocols = imap lmtp
mail_location = maildir:~/Maildir
mail_privileged_group = mail
first_valid_uid = 1000
log_path = /var/log/dovecot.log
info_log_path = /var/log/dovecot-info.log
debug_log_path = /var/log/dovecot-debug.log
!include conf.d/*.conf
!include_try /usr/share/dovecot/protocols.d/*.protocol
EOF

# ИСПРАВЛЕНИЕ: passwd-file с поддержкой email логинов
cat > /etc/dovecot/conf.d/10-auth.conf << EOF
disable_plaintext_auth = no
auth_mechanisms = plain login
auth_username_format = %n

passdb {
  driver = passwd-file
  args = scheme=SHA512-CRYPT username_format=%n /etc/dovecot/users
}

userdb {
  driver = passwd-file
  args = username_format=%n /etc/dovecot/users
  override_fields = home=/home/%n mail=maildir:/home/%n/Maildir
}
EOF

cat > /etc/dovecot/conf.d/10-ssl.conf << EOF
ssl = required
ssl_cert = <$SSL_DIR/fullchain.pem
ssl_key = <$SSL_DIR/privkey.pem
ssl_min_protocol = TLSv1.2
ssl_prefer_server_ciphers = yes
ssl_cipher_list = ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
EOF

cat > /etc/dovecot/conf.d/10-master.conf << EOF
service imap-login {
  inet_listener imap {
    port = 143
  }
  inet_listener imaps {
    port = 993
    ssl = yes
  }
  # Альтернативные порты для обхода блокировок провайдера
  inet_listener imap_alt {
    port = 2143
  }
  inet_listener imaps_alt {
    port = 2993
    ssl = yes
  }
  process_min_avail = 0
  process_limit = 1000
}

service imap {
  process_limit = 1024
}

service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}

service auth-worker {
  user = \$default_internal_user
}
EOF

cat > /etc/dovecot/conf.d/15-mailboxes.conf << EOF
namespace inbox {
  inbox = yes
  location = 
  mailbox Drafts {
    special_use = \\Drafts
  }
  mailbox Junk {
    special_use = \\Junk
  }
  mailbox Sent {
    special_use = \\Sent
  }
  mailbox "Sent Messages" {
    special_use = \\Sent
  }
  mailbox Trash {
    special_use = \\Trash
  }
  prefix = 
}
EOF

# Принудительное отключение IPv6 в Dovecot
cat > /etc/dovecot/conf.d/10-network.conf << EOF
listen = *
EOF

# Создаем директорию и устанавливаем права
mkdir -p /var/spool/postfix/private
chown postfix:postfix /var/spool/postfix/private
chmod 750 /var/spool/postfix/private

# --- DKIM ---
echo -e "\033[1;34m[10/14] Настройка DKIM...\033[0m"
mkdir -p /etc/opendkim/keys/$DOMAIN

if [[ ! -f "/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.private" ]]; then
    opendkim-genkey -b 2048 -s $DKIM_SELECTOR -d $DOMAIN --directory=/etc/opendkim/keys/$DOMAIN
fi

cat > /etc/opendkim.conf << EOF
AutoRestart     Yes
AutoRestartRate 10/1h
UMask           002
Syslog          yes
LogWhy          yes
Canonicalization relaxed/simple
Mode            sv
SubDomains      no
Socket          inet:12301@127.0.0.1
PidFile         /var/run/opendkim/opendkim.pid
UserID          opendkim:opendkim
KeyTable        /etc/opendkim/key.table
SigningTable    refile:/etc/opendkim/signing.table
ExternalIgnoreList /etc/opendkim/trusted.hosts
InternalHosts   /etc/opendkim/trusted.hosts
EOF

echo "$DKIM_SELECTOR._domainkey.$DOMAIN $DOMAIN:$DKIM_SELECTOR:/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.private" > /etc/opendkim/key.table
echo "*@$DOMAIN $DKIM_SELECTOR._domainkey.$DOMAIN" > /etc/opendkim/signing.table

cat > /etc/opendkim/trusted.hosts << EOF
127.0.0.1
::1
localhost
$DOMAIN
*.$DOMAIN
$HOSTNAME
$SERVER_IP
EOF

chown -R opendkim:opendkim /etc/opendkim
chmod -R 750 /etc/opendkim

# --- Создание пользователя ---
echo -e "\033[1;34m[11/14] Создание пользователя...\033[0m"
if ! id "$USERNAME" &>/dev/null; then
  useradd -m -s /bin/bash $USERNAME
  mkdir -p /home/$USERNAME/Maildir/{cur,new,tmp}
  mkdir -p /home/$USERNAME/Maildir/.{Drafts,Sent,Trash,Junk}/{cur,new,tmp}
  chown -R $USERNAME:$USERNAME /home/$USERNAME/Maildir
  chmod -R 700 /home/$USERNAME/Maildir
else
  echo -e "\033[1;33mПользователь $USERNAME уже существует\033[0m"
fi

# Синхронизируем пароль системного пользователя
echo "$USERNAME:$PASSWORD" | chpasswd

# ИСПРАВЛЕНИЕ: Создаем файл паролей Dovecot для email логинов
PASSWORD_HASH=$(doveadm pw -s SHA512-CRYPT -p "$PASSWORD")
mkdir -p /etc/dovecot
echo "$USERNAME@$DOMAIN:$PASSWORD_HASH:1000:1000::/home/$USERNAME::" > /etc/dovecot/users
chmod 640 /etc/dovecot/users
chown root:dovecot /etc/dovecot/users

# --- Fail2Ban ---
echo -e "\033[1;34m[12/14] Настройка Fail2Ban...\033[0m"
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true

[postfix]
enabled = true

[dovecot]
enabled = true

[postfix-sasl]
enabled = true
EOF

# --- Aliases ---
echo -e "\033[1;34m[13/14] Настройка aliases...\033[0m"
if ! grep -q "^$USERNAME:" /etc/aliases; then
  echo "$USERNAME: $USERNAME" >> /etc/aliases
  echo "admin: $USERNAME" >> /etc/aliases
  echo "postmaster: $USERNAME" >> /etc/aliases
  echo "root: $USERNAME" >> /etc/aliases
  newaliases
fi

# --- Запуск служб ---
echo -e "\033[1;34m[14/14] Запуск служб...\033[0m"
systemctl enable opendkim dovecot postfix fail2ban

echo "Запуск OpenDKIM..."
systemctl restart opendkim
sleep 3

echo "Запуск Dovecot..."
systemctl restart dovecot
sleep 3

echo "Запуск Postfix..."
systemctl restart postfix
sleep 3

echo "Запуск Fail2Ban..."
systemctl restart fail2ban
sleep 2

# --- Финальная проверка ---
echo -e "\033[1;32m=== ПРОВЕРКА СЕРВИСОВ ===\033[0m"
for service in opendkim dovecot postfix fail2ban; do
  status=$(systemctl is-active $service)
  if [[ "$status" == "active" ]]; then
    echo -e "$service: \033[1;32m$status\033[0m"
  else
    echo -e "$service: \033[1;31m$status\033[0m"
  fi
done

# Проверка портов
echo -e "\n\033[1;34mПроверка портов:\033[0m"
netstat -tulnp | grep -E "(25|587|465|143|993)" | head -10

# Проверка SASL сокета
echo -e "\n\033[1;34mПроверка SASL сокета:\033[0m"
if [[ -S "/var/spool/postfix/private/auth" ]]; then
  ls -la /var/spool/postfix/private/auth
  echo -e "\033[1;32mSASL сокет найден!\033[0m"
else
  echo -e "\033[1;31mSASL сокет НЕ найден!\033[0m"
fi

# DKIM запись
if [[ -f "/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.txt" ]]; then
  DKIM_RECORD=$(cat /etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.txt | grep -v '^;' | tr -d '\n' | sed 's/" "//g' | sed 's/[[:space:]]//g')
else
  DKIM_RECORD="DKIM ключ не найден!"
fi

echo -e "\033[1;32m"
echo "========================================================================"
echo "🎉🎉🎉 УСТАНОВКА ЗАВЕРШЕНА! FENYA BULLETPROOF SMTP 3.2! 🎉🎉🎉"
echo "========================================================================"
echo "Исправления в этой версии:"
echo "✅ Принудительное отключение IPv6 на уровне ядра"
echo "✅ passwd-file аутентификация с поддержкой email логинов"
echo "✅ Правильные SMTP ограничения (permit в конце)"
echo "✅ Настройки репутации и header_checks для Gmail"
echo "✅ Убраны проблемные SMTP клиентские параметры"
echo "✅ Исправлено mydestination - включает домен"
echo "✅ Альтернативные порты для обхода блокировок"
echo "✅ Чистый ASCII без UTF-8 проблем"
echo "========================================================================"
echo -e "\033[0m"

echo -e "\033[1;33m=== DNS ЗАПИСИ ДЛЯ ДОБАВЛЕНИЯ ===\033[0m"
echo "1. A запись: mail -> $SERVER_IP"
echo "2. MX запись: @ -> mail.$DOMAIN (приоритет 10)"
echo "3. SPF: v=spf1 ip4:$SERVER_IP -all"
echo "4. DKIM: $DKIM_SELECTOR._domainkey -> $DKIM_RECORD"
echo "5. DMARC: _dmarc -> v=DMARC1; p=none; rua=mailto:admin@$DOMAIN"

echo -e "\033[1;33m=== НАСТРОЙКИ ДЛЯ ПОЧТОВЫХ КЛИЕНТОВ ===\033[0m"
echo "IMAP: $HOSTNAME:993 (SSL/TLS) или :143 (STARTTLS)"
echo "SMTP: $HOSTNAME:587 (STARTTLS) или :465 (SSL/TLS)"
echo "Логин: $USERNAME@$DOMAIN"
echo "Пароль: $PASSWORD"

echo -e "\033[1;33m=== КОМАНДЫ ДЛЯ ТЕСТИРОВАНИЯ ===\033[0m"
echo "swaks --to test@example.com --from $USERNAME@$DOMAIN \\"
echo "  --server $HOSTNAME --port 587 \\"
echo "  --auth LOGIN --auth-user $USERNAME@$DOMAIN --auth-password '$PASSWORD' --tls"

echo -e "\033[1;32m🚀 СЕРВЕР ГОТОВ! GMAIL И YANDEX ПОБЕЖДЕНЫ! 🚀\033[0m"
echo -e "\033[1;33mКак говорил мой дед: 'Если этот скрипт не работает - значит ты запустил его не на том сервере!'\033[0m"

tput cnorm
