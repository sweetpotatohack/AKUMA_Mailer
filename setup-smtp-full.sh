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
                                                                                                                                        
                    🔥 Фенин BULLETPROOF SMTP сервер со всеми фиксами! 🔥
EOF
echo -e "\033[0m"

# --- Конфигурация (ИЗМЕНИ ЭТИ ПАРАМЕТРЫ!) ---
DOMAIN="${1:-example.com}"          # Ваш домен
HOSTNAME="mail.$DOMAIN"                     
USERNAME="${2:-smtpuser}"                   # SMTP пользователь
PASSWORD="${3:-$(openssl rand -base64 12)}" # Пароль
DKIM_SELECTOR="mail"                        
EMAIL="admin@$DOMAIN"                       
SERVER_IP="${4:-$(curl -s ifconfig.me)}"   # IP сервера
SSL_DIR="/etc/ssl/$HOSTNAME"                

echo -e "\033[1;33m=== КОНФИГУРАЦИЯ ===\033[0m"
echo -e "Домен: \033[1;36m$DOMAIN\033[0m"
echo -e "Hostname: \033[1;36m$HOSTNAME\033[0m"
echo -e "SMTP пользователь: \033[1;36m$USERNAME\033[0m"
echo -e "Пароль: \033[1;36m$PASSWORD\033[0m"
echo -e "IP сервера: \033[1;36m$SERVER_IP\033[0m"
echo ""

# --- Проверка root ---
if [[ $EUID -ne 0 ]]; then
  echo -e "\033[1;31mТребуются права root, сука!\033[0m" >&2
  exit 1
fi

# --- Остановка существующих сервисов ---
echo -e "\033[1;34m[0/12] Остановка существующих сервисов...\033[0m"
systemctl stop postfix dovecot opendkim 2>/dev/null || echo "Сервисы не были запущены"

# --- Установка пакетов ---
echo -e "\033[1;34m[1/12] Установка пакетов...\033[0m"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  postfix dovecot-core dovecot-imapd opendkim opendkim-tools \
  mailutils curl ufw certbot dnsutils swaks net-tools telnet

# --- Настройка hostname ---
echo -e "\033[1;34m[2/12] Настройка hostname...\033[0m"
hostnamectl set-hostname $HOSTNAME
echo "127.0.0.1 $HOSTNAME" >> /etc/hosts

# --- Создание SSL сертификатов ---
echo -e "\033[1;34m[3/12] Создание SSL сертификатов...\033[0m"
mkdir -p $SSL_DIR
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout $SSL_DIR/privkey.pem \
  -out $SSL_DIR/fullchain.pem \
  -subj "/CN=$HOSTNAME"

# --- Настройка Postfix (ОСНОВНАЯ ХУЙНЯ) ---
echo -e "\033[1;34m[4/12] Настройка Postfix (основная хуйня)...\033[0m"

# Backup существующего конфига
cp /etc/postfix/main.cf /etc/postfix/main.cf.backup.$(date +%s) 2>/dev/null || true

cat > /etc/postfix/main.cf <<EOF
# Основные настройки
smtpd_banner = \$myhostname ESMTP
biff = no
append_dot_mydomain = no
compatibility_level = 3.6

# TLS настройки (ИСПРАВЛЕНО!)
smtpd_tls_cert_file = $SSL_DIR/fullchain.pem
smtpd_tls_key_file = $SSL_DIR/privkey.pem
smtpd_tls_security_level = may
smtpd_tls_auth_only = yes
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_ciphers = medium
smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache
smtpd_tls_session_cache_timeout = 3600s
smtpd_tls_received_header = yes
smtpd_tls_loglevel = 1

# SMTP клиент TLS (ДОБАВЛЕНО!)
smtp_tls_security_level = may
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache

# SASL аутентификация (ИСПРАВЛЕНО!)
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
smtpd_sasl_tls_security_options = noanonymous
broken_sasl_auth_clients = yes

# Сетевые настройки (ИСПРАВЛЕНО mydestination!)
myhostname = $HOSTNAME
mydomain = $DOMAIN
mydestination = \$myhostname, localhost.\$mydomain, localhost
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
inet_interfaces = all
inet_protocols = ipv4

# Почтовые ящики
home_mailbox = Maildir/
mailbox_size_limit = 0
recipient_delimiter = +
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases

# DKIM
milter_default_action = accept
milter_protocol = 2
smtpd_milters = inet:localhost:12301
non_smtpd_milters = inet:localhost:12301

# Дополнительные настройки безопасности (ДОБАВЛЕНО!)
smtpd_helo_required = yes
smtpd_helo_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_invalid_helo_hostname, reject_non_fqdn_helo_hostname
smtpd_sender_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_non_fqdn_sender, reject_unknown_sender_domain
smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_non_fqdn_recipient, reject_unknown_recipient_domain, reject_unauth_destination

# Message ID для исправления Gmail проблем (ДОБАВЛЕНО!)
always_add_missing_headers = yes
local_header_rewrite_clients = permit_sasl_authenticated
EOF

# --- Настройка портов submission и smtps (КРИТИЧНО!) ---
echo -e "\033[1;34m[5/12] Настройка портов submission и smtps...\033[0m"

# Backup master.cf
cp /etc/postfix/master.cf /etc/postfix/master.cf.backup.$(date +%s)

# Настройка submission (587) с ПРИНУДИТЕЛЬНЫМ TLS
postconf -M submission/inet="submission inet n - y - - smtpd"
postconf -P "submission/inet/syslog_name=postfix/submission"
postconf -P "submission/inet/smtpd_tls_security_level=encrypt"
postconf -P "submission/inet/smtpd_sasl_auth_enable=yes"
postconf -P "submission/inet/smtpd_tls_auth_only=yes"
postconf -P "submission/inet/smtpd_reject_unlisted_recipient=no"
postconf -P "submission/inet/smtpd_client_restrictions=permit_sasl_authenticated,reject"
postconf -P "submission/inet/smtpd_helo_restrictions=permit_sasl_authenticated,reject"
postconf -P "submission/inet/smtpd_sender_restrictions=permit_sasl_authenticated,reject"
postconf -P "submission/inet/smtpd_recipient_restrictions=permit_sasl_authenticated,reject"

# Настройка smtps (465) с wrapper mode TLS
postconf -M smtps/inet="smtps inet n - y - - smtpd"
postconf -P "smtps/inet/syslog_name=postfix/smtps"
postconf -P "smtps/inet/smtpd_tls_wrappermode=yes"
postconf -P "smtps/inet/smtpd_sasl_auth_enable=yes"
postconf -P "smtps/inet/smtpd_tls_auth_only=yes"
postconf -P "smtps/inet/smtpd_reject_unlisted_recipient=no"
postconf -P "smtps/inet/smtpd_client_restrictions=permit_sasl_authenticated,reject"

# --- Настройка Dovecot (ИСПРАВЛЕНО!) ---
echo -e "\033[1;34m[6/12] Настройка Dovecot...\033[0m"

# Основные настройки аутентификации
cat > /etc/dovecot/conf.d/10-auth.conf <<EOF
disable_plaintext_auth = no
auth_mechanisms = plain login

passdb {
  driver = pam
}

userdb {
  driver = passwd
}
EOF

# Настройки SSL
cat > /etc/dovecot/conf.d/10-ssl.conf <<EOF
ssl = required
ssl_cert = <$SSL_DIR/fullchain.pem
ssl_key = <$SSL_DIR/privkey.pem
ssl_min_protocol = TLSv1.2
ssl_prefer_server_ciphers = yes
ssl_cipher_list = ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
EOF

# Настройки почтовых ящиков
cat > /etc/dovecot/conf.d/10-mail.conf <<EOF
mail_location = maildir:~/Maildir
mail_privileged_group = mail
first_valid_uid = 1000
EOF

# Настройка SASL сокета для Postfix (КРИТИЧНО!)
cat > /etc/dovecot/conf.d/10-master.conf <<EOF
service imap-login {
  inet_listener imap {
    port = 0
  }
  inet_listener imaps {
    port = 993
    ssl = yes
  }
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

# Создаем директорию и устанавливаем права (ВАЖНО!)
mkdir -p /var/spool/postfix/private
chown postfix:postfix /var/spool/postfix/private
chmod 750 /var/spool/postfix/private

# --- Настройка OpenDKIM (ИСПРАВЛЕНО ПРАВА!) ---
echo -e "\033[1;34m[7/12] Настройка OpenDKIM...\033[0m"
mkdir -p /etc/opendkim/keys/$DOMAIN
opendkim-genkey -b 2048 -s $DKIM_SELECTOR -d $DOMAIN -D /etc/opendkim/keys/$DOMAIN
chown -R opendkim:opendkim /etc/opendkim/keys
chmod -R 750 /etc/opendkim/keys

cat > /etc/opendkim.conf <<EOF
AutoRestart     Yes
AutoRestartRate 10/1h
UMask           002
Syslog          yes
LogWhy          yes
Canonicalization relaxed/simple
Mode            sv
SubDomains      no
Socket          inet:12301@localhost
PidFile         /var/run/opendkim/opendkim.pid
UserID          opendkim:opendkim
KeyTable        /etc/opendkim/key.table
SigningTable    refile:/etc/opendkim/signing.table
ExternalIgnoreList /etc/opendkim/trusted.hosts
InternalHosts   /etc/opendkim/trusted.hosts
EOF

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
*.$DOMAIN
$HOSTNAME
EOF

# --- Создание пользователя ---
echo -e "\033[1;34m[8/12] Создание пользователя...\033[0m"
if ! id "$USERNAME" &>/dev/null; then
  useradd -m -s /bin/bash $USERNAME
  echo "$USERNAME:$PASSWORD" | chpasswd
  mkdir -p /home/$USERNAME/Maildir/{cur,new,tmp}
  chown -R $USERNAME:$USERNAME /home/$USERNAME/Maildir
  chmod -R 700 /home/$USERNAME/Maildir
else
  echo -e "\033[1;33mПользователь $USERNAME уже существует, пропускаем создание.\033[0m"
fi

# --- Получение Let's Encrypt сертификата ---
echo -e "\033[1;34m[9/12] Попытка получения Let's Encrypt сертификата...\033[0m"
ufw allow 80/tcp
if certbot certonly --standalone -d $HOSTNAME --noninteractive --agree-tos --email $EMAIL; then
  echo -e "\033[1;32mLet's Encrypt сертификат получен успешно!\033[0m"
  SSL_DIR="/etc/letsencrypt/live/$HOSTNAME"
  
  # Обновляем конфиги с новыми путями к сертификатам
  sed -i "s|ssl_cert = .*|ssl_cert = <$SSL_DIR/fullchain.pem|" /etc/dovecot/conf.d/10-ssl.conf
  sed -i "s|ssl_key = .*|ssl_key = <$SSL_DIR/privkey.pem|" /etc/dovecot/conf.d/10-ssl.conf
  postconf -e "smtpd_tls_cert_file=$SSL_DIR/fullchain.pem"
  postconf -e "smtpd_tls_key_file=$SSL_DIR/privkey.pem"
else
  echo -e "\033[1;33mНе удалось получить Let's Encrypt сертификат, используем самоподписанные...\033[0m"
fi

# --- Настройка фаервола ---
echo -e "\033[1;34m[10/12] Настройка фаервола...\033[0m"
ufw allow 22,25,80,443,587,465,993/tcp
ufw --force enable

# --- Обновление aliases ---
echo -e "\033[1;34m[11/12] Обновление aliases...\033[0m"
if ! grep -q "^$USERNAME:" /etc/aliases; then
  echo "$USERNAME: $USERNAME" >> /etc/aliases
  echo "admin: $USERNAME" >> /etc/aliases
  echo "postmaster: $USERNAME" >> /etc/aliases
  echo "root: $USERNAME" >> /etc/aliases
  newaliases
fi

# --- Запуск сервисов в правильном порядке ---
echo -e "\033[1;34m[12/12] Запуск сервисов...\033[0m"
systemctl enable opendkim dovecot postfix

echo "Запуск OpenDKIM..."
systemctl start opendkim
sleep 3

echo "Запуск Dovecot..."
systemctl start dovecot
sleep 3

echo "Запуск Postfix..."
systemctl start postfix
sleep 3

# --- Проверка работы сервисов ---
echo -e "\033[1;32m=== ПРОВЕРКА СЕРВИСОВ ===\033[0m"
for service in opendkim dovecot postfix; do
  status=$(systemctl is-active $service)
  if [[ "$status" == "active" ]]; then
    echo -e "$service: \033[1;32m$status\033[0m"
  else
    echo -e "$service: \033[1;31m$status\033[0m"
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
  echo -e "\033[1;32mSASL сокет найден!\033[0m"
else
  echo -e "\033[1;31mSASL сокет НЕ найден!\033[0m"
  echo "Перезапускаем Dovecot..."
  systemctl restart dovecot
  sleep 2
  ls -la /var/spool/postfix/private/auth 2>/dev/null || echo "Все еще нет сокета"
fi

# --- Проверка TLS настроек ---
echo -e "\n\033[1;34mПроверка TLS настроек:\033[0m"
echo "Submission TLS: $(postconf -P submission/inet/smtpd_tls_security_level)"
echo "SMTPS wrapper: $(postconf -P smtps/inet/smtpd_tls_wrappermode)"

# --- Вывод результатов ---
echo -e "\033[1;32m\n=== SMTP СЕРВЕР УСПЕШНО НАСТРОЕН! ===\033[0m"
echo -e "Домен: \033[1;33m$DOMAIN\033[0m"
echo -e "Хост: \033[1;33m$HOSTNAME\033[0m"
echo -e "Пользователь: \033[1;33m$USERNAME\033[0m"
echo -e "Пароль: \033[1;33m$PASSWORD\033[0m"
echo -e "IP сервера: \033[1;33m$SERVER_IP\033[0m"

echo -e "\n\033[1;32m=== DNS ЗАПИСИ ДЛЯ ДОБАВЛЕНИЯ ===\033[0m"

# A запись
echo -e "\033[1;34m1. A запись для почтового сервера:\033[0m"
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
echo "Значение: v=spf1 ip4:$SERVER_IP -all"
echo "TTL: 3600"

# DKIM запись
echo -e "\n\033[1;34m4. DKIM запись:\033[0m"
echo "Тип: TXT"
echo "Имя: $DKIM_SELECTOR._domainkey"
if [[ -f "/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.txt" ]]; then
  DKIM_RECORD=$(cat /etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.txt | grep -v '^;' | tr -d '\n' | sed 's/" "//g' | sed 's/[[:space:]]//g')
  echo "Значение: $DKIM_RECORD"
else
  echo "Значение: DKIM ключ не найден!"
fi
echo "TTL: 3600"

# DMARC запись
echo -e "\n\033[1;34m5. DMARC запись:\033[0m"
echo "Тип: TXT"
echo "Имя: _dmarc"
echo "Значение: v=DMARC1; p=none; rua=mailto:$EMAIL"
echo "TTL: 3600"

# Команды для тестирования
echo -e "\n\033[1;32m=== КОМАНДЫ ДЛЯ ТЕСТИРОВАНИЯ ===\033[0m"

echo -e "\n\033[1;34mТест через порт 587 (STARTTLS):\033[0m"
echo "swaks --to test@example.com --from $USERNAME@$DOMAIN \\"
echo "  --server $HOSTNAME --port 587 \\"
echo "  --auth LOGIN --auth-user $USERNAME --auth-password '$PASSWORD' --tls"

echo -e "\n\033[1;34mТест через порт 465 (SSL):\033[0m"
echo "swaks --to test@example.com --from $USERNAME@$DOMAIN \\"
echo "  --server $HOSTNAME --port 465 \\"
echo "  --auth LOGIN --auth-user $USERNAME --auth-password '$PASSWORD' --tls-on-connect"

echo -e "\n\033[1;34mТест локальной доставки:\033[0m"
echo "swaks --to $USERNAME@$DOMAIN --from test@$DOMAIN \\"
echo "  --server localhost --port 587 \\"
echo "  --auth LOGIN --auth-user $USERNAME --auth-password '$PASSWORD' --tls"

echo -e "\n\033[1;32m=== НАСТРОЙКИ ДЛЯ GOPHISH ===\033[0m"
echo -e "\033[1;34mHost:\033[0m $HOSTNAME:587"
echo -e "\033[1;34mUsername:\033[0m $USERNAME@$DOMAIN"
echo -e "\033[1;34mPassword:\033[0m $PASSWORD"
echo -e "\033[1;34mFrom:\033[0m любой@$DOMAIN"
echo -e "\033[1;34mTLS:\033[0m Enabled (STARTTLS)"
echo -e "\033[1;34mIgnore Cert Errors:\033[0m False"

echo -e "\n\033[1;33mКак говорил мой дед: 'Если SMTP все еще не работает - значит у тебя руки не из того места растут!' 😄\033[0m"

echo -e "\n\033[1;36m=== ИСПОЛЬЗОВАНИЕ СКРИПТА ===\033[0m"
echo "Использование: $0 [домен] [пользователь] [пароль] [IP]"
echo "Пример: $0 example.com mailuser mypassword 1.2.3.4"
echo "Если параметры не указаны, используются значения по умолчанию."

tput cnorm
