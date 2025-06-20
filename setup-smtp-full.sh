#!/bin/bash
set -e
tput civis

echo -e "\033[1;32m"
cat << "EOF"
 ███████╗███╗   ███╗████████╗██████╗     ██████╗ ██╗   ██╗██╗     ██╗     ███████╗████████╗██████╗ ██████╗  ██████╗  ██████╗ ███████╗
 ██╔════╝████╗ ████║╚══██╔══╝██╔══██╗    ██╔══██╗██║   ██║██║     ██║     ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔═══██╗██╔═══██╗██╔════╝
 ███████╗██╔████╔██║   ██║   ██████╔╝    ██████╔╝██║   ██║██║     ██║     █████╗     ██║   ██████╔╝██████╔╝██║   ██║██║   ██║█████╗  
 ╚════██║██║╚██╔╝██║   ██║   ██╔═══╝     ██╔══██╗██║   ██║██║     ██║     ██╔══╝     ██║   ██╔═══╝ ██╔══██╗██║   ██║██║   ██║██╔══╝  
 ███████║██║ ╚═╝ ██║   ██║   ██║         ██████╔╝╚██████╔╝███████╗███████╗███████╗   ██║   ██║     ██║  ██║╚██████╔╝╚██████╔╝██║     
 ╚══════╝╚═╝     ╚═╝   ╚═╝   ╚═╝         ╚═════╝  ╚═════╝ ╚══════╝╚══════╝╚══════╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝     
                                                                                                                                        
                    🔥 ФЕНИН BULLETPROOF SMTP 2.0 - ТЕПЕРЬ БЕЗ ГОВНА! 🔥
                             Made by Fenya - legendary hacker & microservices guru
EOF
echo -e "\033[0m"

# --- Конфигурация (ИЗМЕНИ ЭТИ ПАРАМЕТРЫ!) ---
DOMAIN="${1:-example.com}"          
HOSTNAME="mail.$DOMAIN"                     
USERNAME="${2:-smtpuser}"                   
PASSWORD="${3:-$(openssl rand -base64 12)}" 
DKIM_SELECTOR="mail"                        
EMAIL="dmitriyvisotskiydr15061991@gmail.com"  # Твоя почта для Let's Encrypt
SERVER_IP="${4:-$(curl -s ifconfig.me)}"   
SSL_DIR="/etc/letsencrypt/live/$HOSTNAME"   # Сразу планируем Let's Encrypt

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
  echo -e "\033[1;31mТребуются права root, сука! Без них ничего не получится!\033[0m" >&2
  exit 1
fi

# --- Проверка домена ---
echo -e "\033[1;34m[0/15] Проверка DNS домена...\033[0m"
if ! dig +short A $HOSTNAME | grep -q "$SERVER_IP"; then
  echo -e "\033[1;33mВНИМАНИЕ: DNS запись для $HOSTNAME не указывает на $SERVER_IP\033[0m"
  echo -e "\033[1;33mДобавьте A запись: mail.$DOMAIN -> $SERVER_IP перед продолжением!\033[0m"
  read -p "Продолжить без проверки DNS? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Настройте DNS и запустите скрипт снова."
    exit 1
  fi
fi

# --- Остановка существующих сервисов ---
echo -e "\033[1;34m[1/15] Остановка существующих сервисов...\033[0m"
systemctl stop postfix dovecot opendkim apache2 nginx 2>/dev/null || echo "Некоторые сервисы не были запущены"

# --- Установка пакетов ---
echo -e "\033[1;34m[2/15] Обновление системы и установка пакетов...\033[0m"
apt-get update -qq
apt-get upgrade -y -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  postfix dovecot-core dovecot-imapd dovecot-lmtpd opendkim opendkim-tools \
  mailutils curl wget ufw iptables-persistent certbot dnsutils swaks net-tools telnet \
  rsyslog logrotate fail2ban

# --- Настройка hostname ---
echo -e "\033[1;34m[3/15] Настройка hostname...\033[0m"
hostnamectl set-hostname $HOSTNAME
echo "127.0.0.1 $HOSTNAME localhost" > /etc/hosts
echo "$SERVER_IP $HOSTNAME mail" >> /etc/hosts

# --- Настройка временного SSL для получения Let's Encrypt ---
echo -e "\033[1;34m[4/15] Создание временных SSL сертификатов...\033[0m"
TEMP_SSL_DIR="/etc/ssl/temp-$HOSTNAME"
mkdir -p $TEMP_SSL_DIR
openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
  -keyout $TEMP_SSL_DIR/privkey.pem \
  -out $TEMP_SSL_DIR/fullchain.pem \
  -subj "/CN=$HOSTNAME"

# --- Получение Let's Encrypt сертификата (РАНЬШЕ НАСТРОЙКИ СЕРВИСОВ!) ---
echo -e "\033[1;34m[5/15] Получение Let's Encrypt сертификата...\033[0m"

# Открываем порт 80 временно
ufw allow 80/tcp
iptables -I INPUT -p tcp --dport 80 -j ACCEPT

# Получаем сертификат
if certbot certonly --standalone -d $HOSTNAME --noninteractive --agree-tos --email $EMAIL --force-renewal; then
  echo -e "\033[1;32mLet's Encrypt сертификат получен успешно! Ебашим дальше!\033[0m"
  # Проверяем, что файлы действительно существуют
  if [[ -f "$SSL_DIR/fullchain.pem" && -f "$SSL_DIR/privkey.pem" ]]; then
    echo -e "\033[1;32mСертификаты найдены в $SSL_DIR\033[0m"
  else
    echo -e "\033[1;31mОШИБКА: Сертификаты не найдены после получения!\033[0m"
    echo "Используем временные сертификаты..."
    SSL_DIR="$TEMP_SSL_DIR"
  fi
else
  echo -e "\033[1;33mНе удалось получить Let's Encrypt сертификат, используем временные...\033[0m"
  SSL_DIR="$TEMP_SSL_DIR"
fi

# Закрываем порт 80 (пока)
ufw delete allow 80/tcp 2>/dev/null || true
iptables -D INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || true

# --- Настройка автообновления сертификатов ---
echo -e "\033[1;34m[6/15] Настройка автообновления сертификатов...\033[0m"
cat > /etc/cron.d/certbot-renewal <<EOF
# Обновление Let's Encrypt сертификатов каждые 12 часов
0 */12 * * * root certbot renew --quiet --deploy-hook "systemctl reload postfix dovecot"
EOF

# --- Настройка фаервола и iptables (КРИТИЧНО!) ---
echo -e "\033[1;34m[7/15] Настройка фаervola и iptables...\033[0m"

# Очищаем старые правила
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Базовые правила
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Разрешаем loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Разрешаем установленные соединения
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Открываем нужные порты
iptables -A INPUT -p tcp --dport 22 -j ACCEPT    # SSH
iptables -A INPUT -p tcp --dport 25 -j ACCEPT    # SMTP
iptables -A INPUT -p tcp --dport 80 -j ACCEPT    # HTTP (для certbot)
iptables -A INPUT -p tcp --dport 443 -j ACCEPT   # HTTPS
iptables -A INPUT -p tcp --dport 587 -j ACCEPT   # Submission
iptables -A INPUT -p tcp --dport 465 -j ACCEPT   # SMTPS
iptables -A INPUT -p tcp --dport 993 -j ACCEPT   # IMAPS

# Защита от DDoS
iptables -A INPUT -p tcp --dport 25 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
iptables -A INPUT -p tcp --dport 587 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
iptables -A INPUT -p tcp --dport 465 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT

# Сохраняем правила
iptables-save > /etc/iptables/rules.v4

# Настройка UFW как дополнительный слой
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22,25,80,443,587,465,993/tcp
ufw --force enable

# --- Настройка Postfix (ОСНОВНАЯ ХУЙНЯ ИСПРАВЛЕНА!) ---
echo -e "\033[1;34m[8/15] Настройка Postfix (основная хуйня)...\033[0m"

# Backup существующего конфига
cp /etc/postfix/main.cf /etc/postfix/main.cf.backup.$(date +%s) 2>/dev/null || true

cat > /etc/postfix/main.cf <<EOF
# Основные настройки
smtpd_banner = \$myhostname ESMTP \$mail_name
biff = no
append_dot_mydomain = no
readme_directory = no
compatibility_level = 3.6

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

# Сетевые настройки 
myhostname = $HOSTNAME
mydomain = $DOMAIN
myorigin = \$mydomain
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
inet_interfaces = all
inet_protocols = ipv4

# Почтовые ящики и доставка
home_mailbox = Maildir/
mailbox_size_limit = 0
message_size_limit = 52428800
recipient_delimiter = +
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases

# Настройки доставки
local_recipient_maps = proxy:unix:passwd.byname \$alias_maps
unknown_local_recipient_reject_code = 550

# DKIM и Milter
milter_default_action = accept
milter_protocol = 6
smtpd_milters = inet:localhost:12301
non_smtpd_milters = inet:localhost:12301

# Настройки безопасности (УЛУЧШЕНО!)
smtpd_helo_required = yes
smtpd_delay_reject = yes
smtpd_client_restrictions = 
  permit_mynetworks,
  permit_sasl_authenticated,
  reject_rbl_client zen.spamhaus.org,
  reject_rbl_client bl.spamcop.net,
  permit

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

# Дополнительные настройки
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
EOF

# --- Настройка портов submission и smtps (УЛУЧШЕНО!) ---
echo -e "\033[1;34m[9/15] Настройка портов submission и smtps...\033[0m"

# Backup master.cf
cp /etc/postfix/master.cf /etc/postfix/master.cf.backup.$(date +%s)

# Убираем старые настройки
sed -i '/^submission/d' /etc/postfix/master.cf
sed -i '/^smtps/d' /etc/postfix/master.cf
sed -i '/^  -o /d' /etc/postfix/master.cf

# Добавляем правильную конфигурацию submission (587)
cat >> /etc/postfix/master.cf <<EOF

# Submission port 587 - для аутентифицированных пользователей
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
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING

# SMTPS port 465 - SSL wrapper mode
smtps     inet  n       -       y       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o smtpd_helo_restrictions=permit_sasl_authenticated,reject
  -o smtpd_sender_restrictions=permit_sasl_authenticated,reject
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
EOF

# --- Настройка Dovecot (ПОЛНОСТЬЮ ПЕРЕПИСАНО!) ---
echo -e "\033[1;34m[10/15] Настройка Dovecot (IMAP сервер)...\033[0m"

# Основные настройки
cat > /etc/dovecot/dovecot.conf <<EOF
# Основные протоколы
protocols = imap lmtp

# Настройки логирования
log_path = /var/log/dovecot.log
info_log_path = /var/log/dovecot-info.log
debug_log_path = /var/log/dovecot-debug.log

# Включаем необходимые конфиги
!include conf.d/*.conf
!include_try /usr/share/dovecot/protocols.d/*.protocol
EOF

# Настройки аутентификации
cat > /etc/dovecot/conf.d/10-auth.conf <<EOF
# Отключаем plaintext auth только без TLS
disable_plaintext_auth = yes
auth_mechanisms = plain login

# Настройки базы паролей
passdb {
  driver = pam
}

userdb {
  driver = passwd
}

# Настройки для Postfix SASL
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
EOF

# Настройки SSL
cat > /etc/dovecot/conf.d/10-ssl.conf <<EOF
# SSL настройки
ssl = required
ssl_cert = <$SSL_DIR/fullchain.pem
ssl_key = <$SSL_DIR/privkey.pem

# Настройки протоколов и шифров
ssl_min_protocol = TLSv1.2
ssl_cipher_list = ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
ssl_prefer_server_ciphers = yes

# DH параметры
ssl_dh = </usr/share/dovecot/dh.pem
EOF

# Настройки почтовых ящиков
cat > /etc/dovecot/conf.d/10-mail.conf <<EOF
# Расположение почты
mail_location = maildir:~/Maildir

# Права и пользователи
mail_privileged_group = mail
first_valid_uid = 1000
last_valid_uid = 0

# Настройки namespace
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
}
EOF

# Настройки сервисов
cat > /etc/dovecot/conf.d/10-master.conf <<EOF
# Настройки сервисов
service imap-login {
  inet_listener imap {
    port = 0  # Отключаем незащищенный IMAP
  }
  inet_listener imaps {
    port = 993
    ssl = yes
  }
  
  # Настройки процессов
  process_min_avail = 0
  process_limit = 1000
}

service imap {
  process_limit = 1024
}

# Настройки LMTP для локальной доставки
service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    group = postfix
    mode = 0600
    user = postfix
  }
}

# SASL аутентификация для Postfix
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

# Создаем директории и устанавливаем права
mkdir -p /var/spool/postfix/private
chown postfix:postfix /var/spool/postfix/private
chmod 750 /var/spool/postfix/private

# --- Настройка OpenDKIM (ИСПРАВЛЕНЫ ВСЕ ПРАВА!) ---
echo -e "\033[1;34m[11/15] Настройка OpenDKIM...\033[0m"

# Создаем директории
mkdir -p /etc/opendkim/keys/$DOMAIN
cd /etc/opendkim/keys/$DOMAIN

# Генерируем ключи
opendkim-genkey -b 2048 -s $DKIM_SELECTOR -d $DOMAIN

# Правильно устанавливаем права (КРИТИЧНО!)
chown -R opendkim:opendkim /etc/opendkim
chmod -R 750 /etc/opendkim
chmod 640 /etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.private

# Основная конфигурация OpenDKIM
cat > /etc/opendkim.conf <<EOF
# Основные настройки
AutoRestart             Yes
AutoRestartRate         10/1h
UMask                   002
Syslog                  yes
SyslogSuccess           Yes
LogWhy                  yes

# Криптографические настройки
Canonicalization        relaxed/simple
Mode                    sv
SubDomains              no

# Сетевые настройки
Socket                  inet:12301@localhost
PidFile                 /run/opendkim/opendkim.pid

# Пользователь и группа
UserID                  opendkim:opendkim

# Файлы конфигурации
KeyTable                /etc/opendkim/key.table
SigningTable            refile:/etc/opendkim/signing.table
ExternalIgnoreList      /etc/opendkim/trusted.hosts
InternalHosts           /etc/opendkim/trusted.hosts

# Дополнительные настройки безопасности
RequireSafeKeys         yes
TrustAnchorFile         /usr/share/dns/root.key
EOF

# Таблица ключей
cat > /etc/opendkim/key.table <<EOF
$DKIM_SELECTOR._domainkey.$DOMAIN $DOMAIN:$DKIM_SELECTOR:/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.private
EOF

# Таблица подписи
cat > /etc/opendkim/signing.table <<EOF
*@$DOMAIN $DKIM_SELECTOR._domainkey.$DOMAIN
EOF

# Доверенные хосты
cat > /etc/opendkim/trusted.hosts <<EOF
127.0.0.1
::1
localhost
$DOMAIN
*.$DOMAIN
$HOSTNAME
$SERVER_IP
EOF

# Финальная установка прав
chown -R opendkim:opendkim /etc/opendkim
chmod -R 750 /etc/opendkim
chmod 640 /etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.private

# --- Создание пользователя ---
echo -e "\033[1;34m[12/15] Создание пользователя...\033[0m"
if ! id "$USERNAME" &>/dev/null; then
  useradd -m -s /bin/bash $USERNAME
  echo "$USERNAME:$PASSWORD" | chpasswd
  
  # Создаем структуру Maildir
  mkdir -p /home/$USERNAME/Maildir/{cur,new,tmp}
  mkdir -p /home/$USERNAME/Maildir/.{Drafts,Sent,Trash,Junk}/{cur,new,tmp}
  
  # Устанавливаем права
  chown -R $USERNAME:$USERNAME /home/$USERNAME/Maildir
  chmod -R 700 /home/$USERNAME/Maildir
  
  echo -e "\033[1;32mПользователь $USERNAME создан с паролем: $PASSWORD\033[0m"
else
  echo -e "\033[1;33mПользователь $USERNAME уже существует, обновляем пароль.\033[0m"
  echo "$USERNAME:$PASSWORD" | chpasswd
fi

# --- Настройка Fail2Ban для защиты ---
echo -e "\033[1;34m[13/15] Настройка Fail2Ban...\033[0m"
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true

[postfix]
enabled = true
port = smtp,465,submission
filter = postfix
logpath = /var/log/mail.log
maxretry = 3

[dovecot]
enabled = true
port = pop3,pop3s,imap,imaps,submission,465,sieve
filter = dovecot
logpath = /var/log/mail.log
maxretry = 3
EOF

# --- Обновление aliases ---
echo -e "\033[1;34m[14/15] Обновление aliases...\033[0m"
# Сохраняем оригинальные aliases
cp /etc/aliases /etc/aliases.backup.$(date +%s) 2>/dev/null || true

# Добавляем новые aliases если их нет
if ! grep -q "^$USERNAME:" /etc/aliases; then
  echo "$USERNAME: $USERNAME" >> /etc/aliases
fi
if ! grep -q "^admin:" /etc/aliases; then
  echo "admin: $USERNAME" >> /etc/aliases
fi
if ! grep -q "^postmaster:" /etc/aliases; then
  echo "postmaster: $USERNAME" >> /etc/aliases
fi
if ! grep -q "^root:" /etc/aliases; then
  echo "root: $USERNAME" >> /etc/aliases
fi

newaliases

# --- Запуск сервисов в правильном порядке ---
echo -e "\033[1;34m[15/15] Запуск сервисов...\033[0m"

# Включаем автозапуск
systemctl enable opendkim dovecot postfix fail2ban rsyslog

# Перезапускаем сервисы логирования
systemctl restart rsyslog

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

# --- КОМПЛЕКСНАЯ ПРОВЕРКА РАБОТЫ СЕРВИСОВ ---
echo -e "\033[1;32m=== ПРОВЕРКА СЕРВИСОВ ===\033[0m"
SERVICES_OK=true

for service in opendkim dovecot postfix fail2ban; do
  status=$(systemctl is-active $service)
  if [[ "$status" == "active" ]]; then
    echo -e "$service: \033[1;32m$status\033[0m"
  else
    echo -e "$service: \033[1;31m$status\033[0m"
    SERVICES_OK=false
    echo "Лог ошибок $service:"
    journalctl -u $service --lines=5 --no-pager
  fi
done

# --- Проверка портов ---
echo -e "\n\033[1;34mПроверка портов:\033[0m"
netstat -tulnp | grep -E "(25|587|465|993)" | while read line; do
  echo "$line"
done

# --- Проверка SASL сокета ---
echo -e "\n\033[1;34mПроверка SASL сокета:\033[0m"
if [[ -S "/var/spool/postfix/private/auth" ]]; then
  ls -la /var/spool/postfix/private/auth
  echo -e "\033[1;32mSASL сокет найден и работает!\033[0m"
else
  echo -e "\033[1;31mSASL сокет НЕ найден! Перезапускаем Dovecot...\033[0m"
  systemctl restart dovecot
  sleep 3
  ls -la /var/spool/postfix/private/auth 2>/dev/null || echo "Все еще нет сокета - проверьте конфигурацию!"
fi

# --- Проверка SSL сертификатов ---
echo -e "\n\033[1;34mПроверка SSL сертификатов:\033[0m"
if [[ -f "$SSL_DIR/fullchain.pem" ]]; then
  echo -e "\033[1;32mSSL сертификат найден: $SSL_DIR/fullchain.pem\033[0m"
  echo "Срок действия сертификата:"
  openssl x509 -in $SSL_DIR/fullchain.pem -noout -dates
else
  echo -e "\033[1;31mSSL сертификат НЕ найден!\033[0m"
fi

# --- Проверка DKIM ключа ---
echo -e "\n\033[1;34mПроверка DKIM ключа:\033[0m"
if [[ -f "/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.txt" ]]; then
  echo -e "\033[1;32mDKIM ключ найден!\033[0m"
else
  echo -e "\033[1;31mDKIM ключ НЕ найден!\033[0m"
fi

# --- Тест отправки письма ---
echo -e "\n\033[1;34mТест отправки локального письма...\033[0m"
if command -v swaks >/dev/null 2>&1; then
  echo "test" | swaks --to $USERNAME@$DOMAIN --from test@$DOMAIN --server localhost --auth LOGIN --auth-user $USERNAME --auth-password "$PASSWORD" --tls || echo "Локальный тест не прошел"
fi

# --- ФИНАЛЬНЫЙ ВЫВОД РЕЗУЛЬТАТОВ ---
if [[ "$SERVICES_OK" == "true" ]]; then
  echo -e "\033[1;32m\n🔥🔥🔥 SMTP СЕРВЕР УСПЕШНО НАСТРОЕН И ЕБАШИТ! 🔥🔥🔥\033[0m"
else
  echo -e "\033[1;33m\n⚠️  SMTP СЕРВЕР НАСТРОЕН, НО ЕСТЬ ПРОБЛЕМЫ С СЕРВИСАМИ ⚠️\033[0m"
  echo -e "\033[1;33mПроверьте логи выше и исправьте ошибки\033[0m"
fi

echo -e "\033[1;36m\n=== КОНФИГУРАЦИЯ СЕРВЕРА ===\033[0m"
echo -e "Домен: \033[1;33m$DOMAIN\033[0m"
echo -e "Хост: \033[1;33m$HOSTNAME\033[0m"
echo -e "Пользователь: \033[1;33m$USERNAME@$DOMAIN\033[0m"
echo -e "Пароль: \033[1;33m$PASSWORD\033[0m"
echo -e "IP сервера: \033[1;33m$SERVER_IP\033[0m"
echo -e "SSL сертификаты: \033[1;33m$SSL_DIR\033[0m"

echo -e "\n\033[1;32m=== DNS ЗАПИСИ ДЛЯ ДОБАВЛЕНИЯ ===\033[0m"

# A запись
echo -e "\n\033[1;34m1. A запись для почтового сервера:\033[0m"
echo "Тип: A"
echo "Имя: mail"
echo "Значение: $SERVER_IP"
echo "TTL: 3600"

# MX запись
echo -e "\n\033[1;34m2. MX запись:\033[0m"
echo "Тип: MX"
echo "Имя: @"
echo "Значение: $HOSTNAME"
echo "Приоритет: 10"
echo "TTL: 3600"

# SPF запись
echo -e "\n\033[1;34m3. SPF запись:\033[0m"
echo "Тип: TXT"
echo "Имя: @"
echo "Значение: v=spf1 ip4:$SERVER_IP include:$HOSTNAME -all"
echo "TTL: 3600"

# DKIM запись
echo -e "\n\033[1;34m4. DKIM запись:\033[0m"
echo "Тип: TXT"
echo "Имя: $DKIM_SELECTOR._domainkey"
if [[ -f "/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.txt" ]]; then
  DKIM_RECORD=$(grep -v '^;' /etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.txt | tr -d '\n' | tr -d '\t' | sed 's/.*IN[[:space:]]*TXT[[:space:]]*( *//' | sed 's/ *) *$//' | tr -d '"')
  echo "Значение: $DKIM_RECORD"
else
  echo "Значение: DKIM ключ не найден! Проверьте настройки OpenDKIM"
fi
echo "TTL: 3600"

# DMARC запись
echo -e "\n\033[1;34m5. DMARC запись:\033[0m"
echo "Тип: TXT"
echo "Имя: _dmarc"
echo "Значение: v=DMARC1; p=quarantine; rua=mailto:dmarc@$DOMAIN; ruf=mailto:dmarc@$DOMAIN; fo=1"
echo "TTL: 3600"

# Команды для тестирования
echo -e "\n\033[1;32m=== КОМАНДЫ ДЛЯ ТЕСТИРОВАНИЯ ===\033[0m"

echo -e "\n\033[1;34m🔧 Тест SMTP через порт 587 (STARTTLS):\033[0m"
echo "swaks --to test@gmail.com --from $USERNAME@$DOMAIN \\"
echo "  --server $HOSTNAME --port 587 \\"
echo "  --auth LOGIN --auth-user $USERNAME@$DOMAIN --auth-password '$PASSWORD' --tls"

echo -e "\n\033[1;34m🔧 Тест SMTP через порт 465 (SSL):\033[0m"
echo "swaks --to test@gmail.com --from $USERNAME@$DOMAIN \\"
echo "  --server $HOSTNAME --port 465 \\"
echo "  --auth LOGIN --auth-user $USERNAME@$DOMAIN --auth-password '$PASSWORD' --tls-on-connect"

echo -e "\n\033[1;34m🔧 Тест локальной доставки:\033[0m"
echo "swaks --to $USERNAME@$DOMAIN --from test@$DOMAIN \\"
echo "  --server localhost --port 587 \\"
echo "  --auth LOGIN --auth-user $USERNAME@$DOMAIN --auth-password '$PASSWORD' --tls"

echo -e "\n\033[1;34m🔧 Проверка IMAP соединения:\033[0m"
echo "telnet $HOSTNAME 993"

echo -e "\n\033[1;34m🔧 Проверка DNS записей:\033[0m"
echo "dig MX $DOMAIN"
echo "dig TXT $DOMAIN"
echo "dig TXT $DKIM_SELECTOR._domainkey.$DOMAIN"

echo -e "\n\033[1;32m=== НАСТРОЙКИ ДЛЯ ПОЧТОВЫХ КЛИЕНТОВ ===\033[0m"
echo -e "\033[1;34mIMAP сервер:\033[0m $HOSTNAME:993 (SSL/TLS)"
echo -e "\033[1;34mSMTP сервер:\033[0m $HOSTNAME:587 (STARTTLS) или $HOSTNAME:465 (SSL/TLS)"
echo -e "\033[1;34mИмя пользователя:\033[0m $USERNAME@$DOMAIN"
echo -e "\033[1;34mПароль:\033[0m $PASSWORD"
echo -e "\033[1;34mАутентификация:\033[0m Обычный пароль / PLAIN / LOGIN"

echo -e "\n\033[1;32m=== НАСТРОЙКИ ДЛЯ GOPHISH ===\033[0m"
echo -e "\033[1;34mHost:\033[0m $HOSTNAME:587"
echo -e "\033[1;34mUsername:\033[0m $USERNAME@$DOMAIN"  
echo -e "\033[1;34mPassword:\033[0m $PASSWORD"
echo -e "\033[1;34mFrom:\033[0m любой@$DOMAIN"
echo -e "\033[1;34mTLS:\033[0m Enabled (STARTTLS)"
echo -e "\033[1;34mIgnore Cert Errors:\033[0m False"

echo -e "\n\033[1;32m=== ПОЛЕЗНЫЕ КОМАНДЫ ДЛЯ ДИАГНОСТИКИ ===\033[0m"
echo -e "\033[1;34mПроверка логов Postfix:\033[0m tail -f /var/log/mail.log"
echo -e "\033[1;34mПроверка логов Dovecot:\033[0m tail -f /var/log/dovecot.log"
echo -e "\033[1;34mПроверка очереди Postfix:\033[0m postqueue -p"
echo -e "\033[1;34mПерезапуск всех сервисов:\033[0m systemctl restart opendkim dovecot postfix"
echo -e "\033[1;34mПроверка конфигурации Postfix:\033[0m postfix check"
echo -e "\033[1;34mПроверка конфигурации Dovecot:\033[0m doveconf -n"

echo -e "\n\033[1;36m=== ИСПОЛЬЗОВАНИЕ СКРИПТА ===\033[0m"
echo "Использование: $0 [домен] [пользователь] [пароль] [IP]"
echo "Пример: $0 mycompany.com mailuser SuperSecretPass123 1.2.3.4"

echo -e "\n\033[1;33m🎉 Как говорил мой дед-хакер: 'Если почта не уходит - значит либо DNS говно, либо руки кривые, либо провайдер мудак!' 😄\033[0m"
echo -e "\033[1;33m💡 А если все работает - то ты теперь настоящий сисадмин! Welcome to the club! 🚀\033[0m"

tput cnorm
