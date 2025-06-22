cat /root/setup-smtp-bulletproof-FINAL.sh
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
                                                                                                                                        
             🔥 ФЕНИН BULLETPROOF SMTP 3.2 - GMAIL KILLER EDITION! 🔥
              Made by Fenya - legendary hacker & microservices guru
                 ИСПРАВЛЕНЫ ВСЕ ПРОБЛЕМЫ: IPv6, PAM, ОГРАНИЧЕНИЯ!
EOF
echo -e "\033[0m"

# --- Конфигурация (ИЗМЕНИ ЭТИ ПАРАМЕТРЫ!) ---
DOMAIN="${1:-example.com}"          
HOSTNAME="mail.$DOMAIN"                     
USERNAME="${2:-support}"                   
PASSWORD="${3:-$(openssl rand -base64 12)}" 
DKIM_SELECTOR="mail"                        
EMAIL="${4:-admin@$DOMAIN}"  # Твоя почта для Let's Encrypt
SERVER_IP="${5:-$(curl -s ifconfig.me || curl -s ipinfo.io/ip)}"   

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

# --- Обновление системы ---
echo -e "\033[1;34m[1/12] Обновление системы...\033[0m"
export DEBIAN_FRONTEND=noninteractive
apt update -qq && apt upgrade -y -qq

# --- Установка пакетов ---
echo -e "\033[1;34m[2/12] Установка пакетов...\033[0m"
apt install -y -qq postfix dovecot-core dovecot-imapd dovecot-lmtpd \
  opendkim opendkim-tools certbot fail2ban ufw swaks dnsutils curl wget

# --- Настройка hostname ---
echo -e "\033[1;34m[3/12] Настройка hostname...\033[0m"
hostnamectl set-hostname $HOSTNAME
echo "127.0.0.1 $HOSTNAME" >> /etc/hosts

# --- Настройка файервола ---
echo -e "\033[1;34m[4/12] Настройка файервола...\033[0m"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 22,25,80,143,443,465,587,993/tcp
ufw --force enable

# --- SSL сертификат ---
echo -e "\033[1;34m[5/12] Получение SSL сертификата...\033[0m"
systemctl stop nginx apache2 2>/dev/null || true
if certbot certonly --standalone --agree-tos --no-eff-email --email $EMAIL -d $HOSTNAME --non-interactive; then
  SSL_DIR="/etc/letsencrypt/live/$HOSTNAME"
else
  SSL_DIR="/etc/ssl/private"
  mkdir -p $SSL_DIR
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout $SSL_DIR/privkey.pem -out $SSL_DIR/fullchain.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=$HOSTNAME"
fi

# --- Настройка Postfix ---
echo -e "\033[1;34m[6/12] Настройка Postfix...\033[0m"
cat > /etc/postfix/main.cf << EOF
mydomain = $DOMAIN
myhostname = $HOSTNAME
myorigin = \$mydomain
inet_interfaces = all
inet_protocols = ipv4
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
message_size_limit = 52428800
mailbox_size_limit = 0

# TLS настройки
smtpd_tls_cert_file = $SSL_DIR/fullchain.pem
smtpd_tls_key_file = $SSL_DIR/privkey.pem
smtpd_use_tls = yes
smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache
smtpd_tls_security_level = may
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_ciphers = medium
smtpd_tls_exclude_ciphers = aNULL, eNULL, EXPORT, DES, RC4, MD5, PSK, SRP, DSS, AECDH, ADH

# ИСПРАВЛЕНИЕ: Правильные ограничения
smtpd_client_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_rbl_client zen.spamhaus.org, reject_rbl_client bl.spamcop.net, permit
smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_non_fqdn_recipient, reject_unknown_recipient_domain, reject_unauth_destination, reject_rbl_client zen.spamhaus.org, permit
smtpd_sender_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_non_fqdn_sender, reject_unknown_sender_domain, reject_unauth_pipelining, permit

# SASL настройки
smtpd_sasl_auth_enable = yes
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_security_options = noanonymous, noplaintext
smtpd_sasl_tls_security_options = noanonymous
broken_sasl_auth_clients = yes

# SMTP клиент TLS
smtp_tls_security_level = may
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache
smtp_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtp_tls_ciphers = medium

# Настройки для Gmail
smtp_helo_name = $HOSTNAME
smtp_always_send_ehlo = yes
disable_vrfy_command = yes

# DKIM
milter_default_action = accept
milter_protocol = 2
smtpd_milters = inet:localhost:12301
non_smtpd_milters = inet:localhost:12301

# Защита
smtpd_helo_required = yes
smtpd_delay_reject = yes
smtpd_client_connection_count_limit = 50
smtpd_client_connection_rate_limit = 30
smtpd_client_message_rate_limit = 100
smtpd_soft_error_limit = 10
smtpd_hard_error_limit = 20
smtpd_error_sleep_time = 1s

append_dot_mydomain = no
biff = no
recipient_delimiter = +
smtpd_banner = \$myhostname ESMTP \$mail_name
EOF

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

587       inet  n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject_unauth_destination

465       inet  n       -       y       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject_unauth_destination
EOF

# --- Настройка Dovecot ---
echo -e "\033[1;34m[7/12] Настройка Dovecot...\033[0m"
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

# ИСПРАВЛЕНИЕ: passwd-file вместо PAM
cat > /etc/dovecot/conf.d/10-auth.conf << EOF
disable_plaintext_auth = yes
auth_mechanisms = plain login

passdb {
  driver = passwd-file
  args = /etc/dovecot/users/passwd
}

userdb {
  driver = passwd-file
  args = /etc/dovecot/users/passwd
}

service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
EOF

cat > /etc/dovecot/conf.d/10-ssl.conf << EOF
ssl = required
ssl_cert = <$SSL_DIR/fullchain.pem
ssl_key = <$SSL_DIR/privkey.pem
ssl_protocols = !SSLv2 !SSLv3 !TLSv1 !TLSv1.1
ssl_cipher_list = ECDHE+AESGCM:ECDHE+CHACHA20:DHE+AESGCM:DHE+CHACHA20:!aNULL:!SHA1:!AESCCM
ssl_prefer_server_ciphers = yes
ssl_dh = </usr/share/dovecot/dh.pem
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
  process_min_avail = 0
  process_limit = 1000
}

service imap {
  process_limit = 1024
}

service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    group = postfix
    mode = 0600
    user = postfix
  }
}

service auth {
  unix_listener /var/spool/postfix/private/auth {
    group = postfix
    mode = 0660
    user = postfix
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

# --- DKIM ---
echo -e "\033[1;34m[8/12] Настройка DKIM...\033[0m"
mkdir -p /etc/opendkim/keys/$DOMAIN
opendkim-genkey -b 2048 -s $DKIM_SELECTOR -d $DOMAIN --directory=/etc/opendkim/keys/$DOMAIN

cat > /etc/opendkim.conf << EOF
Syslog yes
SyslogSuccess yes
LogWhy yes
Canonicalization relaxed/simple
Mode sv
SubDomains no
OversignHeaders From
AutoRestart yes
AutoRestartRate 10/1M
Background yes
DNSTimeout 5
SignatureAlgorithm rsa-sha256
UserID opendkim
UMask 007
KeyTable refile:/etc/opendkim/key.table
SigningTable refile:/etc/opendkim/signing.table
ExternalIgnoreList /etc/opendkim/trusted.hosts
InternalHosts /etc/opendkim/trusted.hosts
Socket inet:12301@localhost
PidFile /run/opendkim/opendkim.pid
TrustAnchorFile /usr/share/dns/root.key
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
chmod 640 /etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.private

# --- Создание пользователя ---
echo -e "\033[1;34m[9/12] Создание пользователя...\033[0m"
if ! id "$USERNAME" &>/dev/null; then
  useradd -m -s /bin/bash $USERNAME
  echo "$USERNAME:$PASSWORD" | chpasswd
  mkdir -p /home/$USERNAME/Maildir/{cur,new,tmp}
  mkdir -p /home/$USERNAME/Maildir/.{Drafts,Sent,Trash,Junk}/{cur,new,tmp}
  chown -R $USERNAME:$USERNAME /home/$USERNAME/Maildir
  chmod -R 700 /home/$USERNAME/Maildir
else
  echo "$USERNAME:$PASSWORD" | chpasswd
fi

# ИСПРАВЛЕНИЕ: Создаем файл паролей Dovecot
mkdir -p /etc/dovecot/users
PASSWORD_HASH=$(doveadm pw -s SHA512-CRYPT -p "$PASSWORD")
echo "$USERNAME@$DOMAIN:$PASSWORD_HASH:$(id -u $USERNAME):$(id -g $USERNAME)::/home/$USERNAME/:/bin/bash" > /etc/dovecot/users/passwd
chmod 640 /etc/dovecot/users/passwd
chown root:dovecot /etc/dovecot/users/passwd

# --- Fail2Ban ---
echo -e "\033[1;34m[10/12] Настройка Fail2Ban...\033[0m"
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

# --- Запуск служб ---
echo -e "\033[1;34m[11/12] Запуск служб...\033[0m"
systemctl enable opendkim dovecot postfix fail2ban
systemctl restart opendkim
systemctl restart postfix
systemctl restart dovecot
systemctl restart fail2ban

# --- Финальная проверка ---
echo -e "\033[1;34m[12/12] Проверка...\033[0m"
sleep 5

if systemctl is-active --quiet postfix && systemctl is-active --quiet dovecot && systemctl is-active --quiet opendkim; then
  echo -e "\033[1;32mВсе службы запущены успешно!\033[0m"
else
  echo -e "\033[1;31mОшибка в службах!\033[0m"
fi

# DKIM запись
DKIM_RECORD=$(cat /etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.txt | tr -d '\n\t' | sed 's/.*p=/p=/' | sed 's/".*//')

echo -e "\033[1;32m"
cat << "EOF"
🎉🎉🎉 УСТАНОВКА ЗАВЕРШЕНА! 🎉🎉🎉

Исправления:
✅ IPv4 для Gmail совместимости
✅ passwd-file аутентификация
✅ Правильные SMTP ограничения
✅ Настройки репутации
EOF
echo -e "\033[0m"

echo -e "\033[1;33m=== DNS ЗАПИСИ ===\033[0m"
echo "1. A запись: mail -> $SERVER_IP"
echo "2. MX запись: @ -> mail.$DOMAIN (приоритет 10)"
echo "3. SPF: v=spf1 ip4:$SERVER_IP include:mail.$DOMAIN -all"
echo "4. DKIM: mail._domainkey -> v=DKIM1; h=sha256; k=rsa; $DKIM_RECORD"
echo "5. DMARC: _dmarc -> v=DMARC1; p=quarantine; rua=mailto:dmarc@$DOMAIN"

echo -e "\033[1;33m=== НАСТРОЙКИ THUNDERBIRD ===\033[0m"
echo "IMAP: mail.$DOMAIN:993 (SSL/TLS)"
echo "SMTP: mail.$DOMAIN:587 (STARTTLS) или :465 (SSL/TLS)"
echo "Логин: $USERNAME@$DOMAIN"
echo "Пароль: $PASSWORD"

echo -e "\033[1;32m🚀 СЕРВЕР ГОТОВ! GMAIL И YANDEX ПОБЕЖДЕНЫ! 🚀\033[0m"
tput cnorm
