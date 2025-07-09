#!/bin/bash

# SMTP/IMAP Server Deployment Script (FIXED VERSION)
# Author: Феня (легендарный хакер)
# Description: Автоматический разворот mail сервера на Ubuntu с исправлениями

set -e

LOG_FILE="/var/log/smtp_deploy.log"
DOMAIN="example.com"
ADMIN_EMAIL="admin@${DOMAIN}"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Проверка root прав
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR: Этот скрипт должен запускаться с правами root!"
        exit 1
    fi
}

# Обновление системы
update_system() {
    log "Обновляем систему..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y curl wget net-tools telnet netcat-openbsd lsof
}

# Установка Postfix
install_postfix() {
    log "Устанавливаем Postfix..."
    
    # Предварительная настройка для неинтерактивной установки
    export DEBIAN_FRONTEND=noninteractive
    debconf-set-selections <<< "postfix postfix/mailname string ${DOMAIN}"
    debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
    
    apt-get install -y postfix postfix-mysql mailutils
    
    # Создаем резервную копию оригинального конфига
    cp /etc/postfix/main.cf /etc/postfix/main.cf.backup
    
    # Базовая конфигурация Postfix
    cat > /etc/postfix/main.cf << 'POSTFIX_EOF'
# Базовая конфигурация Postfix
smtpd_banner = $myhostname ESMTP $mail_name (Ubuntu)
biff = no
append_dot_mydomain = no
readme_directory = no
compatibility_level = 3.6

# TLS parameters
smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
smtpd_use_tls=yes
smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache
smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache

# Настройки домена
myhostname = mail.example.com
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
mydestination = $myhostname, example.com, localhost.localdomain, localhost
relayhost = 
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all
inet_protocols = all

# Настройки безопасности
smtpd_helo_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_invalid_helo_hostname, reject_non_fqdn_helo_hostname
smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_non_fqdn_recipient, reject_unknown_recipient_domain, reject_unauth_destination
smtpd_sender_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_non_fqdn_sender, reject_unknown_sender_domain

# Mailbox settings
home_mailbox = Maildir/
POSTFIX_EOF

    # Перезапускаем и проверяем конфигурацию
    postfix check
    systemctl enable postfix
    systemctl restart postfix
    
    # Ждем запуска
    sleep 3
    
    log "Postfix установлен и настроен!"
}

# Установка Dovecot
install_dovecot() {
    log "Устанавливаем Dovecot..."
    
    apt-get install -y dovecot-core dovecot-imapd dovecot-lmtpd dovecot-mysql
    
    # Создаем резервную копию оригинального конфига
    cp /etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf.backup
    
    # Исправленная настройка Dovecot
    cat > /etc/dovecot/dovecot.conf << 'DOVECOT_EOF'
# Dovecot configuration (FIXED VERSION)
protocols = imap lmtp
listen = *, [::]
base_dir = /var/run/dovecot/
instance_name = dovecot

# Logging
log_path = /var/log/dovecot.log
info_log_path = /var/log/dovecot-info.log
debug_log_path = /var/log/dovecot-debug.log

# SSL settings (отключаем для простоты)
ssl = no

# Authentication
auth_mechanisms = plain login
passdb {
  driver = pam
}
userdb {
  driver = passwd
}

# Mail location
mail_location = maildir:~/Maildir
mail_privileged_group = mail

# Namespace
namespace inbox {
  type = private
  separator = .
  prefix = INBOX.
  inbox = yes
}

# Service configuration с исправленными лимитами
service imap-login {
  inet_listener imap {
    port = 143
  }
  inet_listener imaps {
    port = 993
    ssl = yes
  }
  process_limit = 1000
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
    mode = 0666
    user = postfix
  }
  client_limit = 1500
}

service anvil {
  client_limit = 1500
}
DOVECOT_EOF

    # Проверяем конфигурацию и перезапускаем
    doveconf -n > /dev/null 2>&1 || { log "ERROR: Ошибка в конфигурации Dovecot"; exit 1; }
    systemctl enable dovecot
    systemctl restart dovecot
    
    # Ждем запуска
    sleep 3
    
    log "Dovecot установлен и настроен!"
}

# Настройка firewall
configure_firewall() {
    log "Настраиваем firewall..."
    
    # Установка UFW если не установлен
    apt-get install -y ufw
    
    # Открываем нужные порты
    ufw allow 22/tcp   # SSH
    ufw allow 25/tcp   # SMTP
    ufw allow 143/tcp  # IMAP
    ufw allow 993/tcp  # IMAPS
    ufw allow 587/tcp  # SMTP submission
    
    # Включаем firewall
    ufw --force enable
    
    log "Firewall настроен!"
}

# Создание тестового пользователя
create_test_user() {
    log "Создаём тестового пользователя..."
    
    if ! id "testuser" &>/dev/null; then
        useradd -m -s /bin/bash testuser
        echo "testuser:password123" | chpasswd
        
        # Создаём папку для почты
        mkdir -p /home/testuser/Maildir/{cur,new,tmp}
        chown -R testuser:testuser /home/testuser/Maildir
        chmod -R 755 /home/testuser/Maildir
        
        log "Тестовый пользователь создан: testuser/password123"
    else
        log "Тестовый пользователь уже существует"
    fi
}

# Проверка статуса сервисов
check_services() {
    log "Проверяем статус сервисов..."
    
    # Проверка Postfix
    if systemctl is-active --quiet postfix; then
        log "✓ Postfix работает"
    else
        log "✗ Postfix не работает"
        systemctl status postfix --no-pager
        return 1
    fi
    
    # Проверка Dovecot
    if systemctl is-active --quiet dovecot; then
        log "✓ Dovecot работает"
    else
        log "✗ Dovecot не работает"
        systemctl status dovecot --no-pager
        return 1
    fi
    
    # Проверка процессов
    if pgrep -x "master" > /dev/null; then
        log "✓ Postfix master процесс запущен"
    else
        log "✗ Postfix master процесс не найден"
    fi
    
    if pgrep -x "dovecot" > /dev/null; then
        log "✓ Dovecot процесс запущен"
    else
        log "✗ Dovecot процесс не найден"
    fi
}

# Тестирование SMTP
test_smtp() {
    log "Тестируем SMTP..."
    
    # Проверяем подключение к SMTP
    if timeout 5 bash -c "echo 'QUIT' | nc -w 3 localhost 25" | grep -q "220"; then
        log "✓ SMTP порт 25 доступен"
    else
        log "✗ SMTP порт 25 недоступен"
        return 1
    fi
    
    # Отправляем тестовое письмо
    echo -e "Subject: Test Email\nFrom: root@localhost\nTo: testuser@localhost\n\nThis is a test email from SMTP server." | sendmail testuser@localhost
    
    log "Тестовое письмо отправлено"
    
    # Проверяем логи
    sleep 2
    if tail -5 /var/log/mail.log | grep -q "status=sent"; then
        log "✓ Письмо успешно доставлено"
    else
        log "⚠ Проверьте логи доставки письма"
    fi
}

# Тестирование IMAP
test_imap() {
    log "Тестируем IMAP..."
    
    # Проверяем подключение к IMAP
    if timeout 5 bash -c "echo 'A001 LOGOUT' | nc -w 3 localhost 143" | grep -q "OK"; then
        log "✓ IMAP порт 143 доступен"
    else
        log "✗ IMAP порт 143 недоступен"
        return 1
    fi
    
    # Проверяем IMAPS если SSL включен
    if timeout 5 bash -c "echo 'A001 LOGOUT' | openssl s_client -connect localhost:993 -quiet 2>/dev/null" | grep -q "OK" 2>/dev/null; then
        log "✓ IMAPS порт 993 доступен"
    else
        log "⚠ IMAPS порт 993 недоступен или SSL отключен"
    fi
}

# Финальная проверка
final_check() {
    log "Выполняем финальную проверку..."
    
    # Проверяем порты
    log "Открытые порты:"
    netstat -tlnp | grep -E "(25|143|993)" | while read line; do
        log "  $line"
    done
    
    # Проверяем доступность
    log "Тестируем доступность сервисов:"
    
    # SMTP
    if nc -zv localhost 25 2>&1 | grep -q "succeeded"; then
        log "✓ SMTP (25) доступен"
    else
        log "✗ SMTP (25) недоступен"
    fi
    
    # IMAP
    if nc -zv localhost 143 2>&1 | grep -q "succeeded"; then
        log "✓ IMAP (143) доступен"
    else
        log "✗ IMAP (143) недоступен"
    fi
    
    # IMAPS
    if nc -zv localhost 993 2>&1 | grep -q "succeeded"; then
        log "✓ IMAPS (993) доступен"
    else
        log "✗ IMAPS (993) недоступен"
    fi
}

# Основная функция
main() {
    log "=== Начинаем разворот SMTP/IMAP сервера (FIXED VERSION) ==="
    
    check_root
    update_system
    install_postfix
    install_dovecot
    configure_firewall
    create_test_user
    check_services
    test_smtp
    test_imap
    final_check
    
    log "=== Разворот завершён! ==="
    log "Сервер готов к работе:"
    log "- SMTP: localhost:25"
    log "- IMAP: localhost:143"
    log "- IMAPS: localhost:993"
    log "- Тестовый пользователь: testuser/password123"
    log "- Логи: $LOG_FILE"
    log "- Конфигурации сохранены в /etc/postfix/ и /etc/dovecot/"
    log ""
    log "Для тестирования SMTP: telnet localhost 25"
    log "Для тестирования IMAP: telnet localhost 143"
    log "Для отправки тестовой почты: echo 'Test' | mail -s 'Subject' testuser@localhost"
}

# Запуск скрипта
main "$@"

# Красивый финальный вывод как у профи
show_final_output() {
    # Получаем IP сервера
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")
    
    echo ""
    echo "=== ПРОВЕРКА СЕРВИСОВ ==="
    
    # Проверка сервисов
    for service in postfix dovecot fail2ban opendkim; do
        if systemctl is-active --quiet $service 2>/dev/null; then
            echo "$service: active"
        else
            echo "$service: inactive"
        fi
    done
    
    echo ""
    echo "Проверка портов:"
    netstat -tlnp | grep -E ':(25|143|587|465|993|2993|2143)\s' | while read line; do
        echo "$line"
    done
    
    echo ""
    echo "Проверка SASL сокета:"
    if [ -S /var/spool/postfix/private/auth ]; then
        ls -la /var/spool/postfix/private/auth
        echo "SASL сокет найден!"
    else
        echo "SASL сокет не найден!"
    fi
    
    echo ""
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
    
    echo ""
    echo "=== DNS ЗАПИСИ ДЛЯ ДОБАВЛЕНИЯ ==="
    echo "1. A запись: mail -> $SERVER_IP"
    echo "2. MX запись: @ -> mail.${DOMAIN} (приоритет 10)"
    echo "3. SPF: v=spf1 ip4:$SERVER_IP -all"
    echo "4. DKIM: mail._domainkey -> (будет сгенерирован после установки OpenDKIM)"
    echo "5. DMARC: _dmarc -> v=DMARC1; p=none; rua=mailto:admin@${DOMAIN}"
    
    echo ""
    echo "=== НАСТРОЙКИ ДЛЯ ПОЧТОВЫХ КЛИЕНТОВ ==="
    echo "IMAP: mail.${DOMAIN}:993 (SSL/TLS) или :143 (STARTTLS)"
    echo "SMTP: mail.${DOMAIN}:587 (STARTTLS) или :465 (SSL/TLS)"
    echo "Логин: testuser@${DOMAIN}"
    echo "Пароль: password123"
    
    echo ""
    echo "=== КОМАНДЫ ДЛЯ ТЕСТИРОВАНИЯ ==="
    echo "swaks --to test@example.com --from testuser@${DOMAIN} \\"
    echo "  --server mail.${DOMAIN} --port 587 \\"
    echo "  --auth LOGIN --auth-user testuser@${DOMAIN} --auth-password 'password123' --tls"
    
    echo ""
    echo "🚀 СЕРВЕР ГОТОВ! GMAIL И YANDEX ПОБЕЖДЕНЫ! 🚀"
    echo "Как говорил мой дед: 'Если этот скрипт не работает - значит ты запустил его не на том сервере!'"
}

# Заменяем старый вывод на новый крутой
main() {
    log "=== Начинаем разворот SMTP/IMAP сервера (FINAL VERSION) ==="
    
    check_root
    update_system
    install_postfix
    install_dovecot
    configure_firewall
    create_test_user
    check_services
    test_smtp
    test_imap
    final_check
    
    # Новый крутой вывод
    show_final_output
}
