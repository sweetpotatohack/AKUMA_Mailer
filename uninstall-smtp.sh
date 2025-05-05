#!/bin/bash

# Остановка и удаление сервисов
systemctl stop postfix dovecot opendkim
systemctl disable postfix dovecot opendkim

# Удаление пакетов
apt-get purge -y postfix opendkim opendkim-tools mailutils dovecot-core dovecot-imapd swaks
apt-get purge -y certbot python3-certbot-nginx
snap remove certbot
snap remove core

# Удаление конфигурационных файлов
rm -rf /etc/postfix /etc/dovecot /etc/opendkim* /etc/letsencrypt
rm -f /etc/mailname
rm -f /etc/cron.d/certbot-renew

# Удаление пользователя (если создавался скриптом)
if id "techsup" &>/dev/null; then
    userdel -r techsup
fi

# Удаление конфигурационного файла
rm -f /root/smtp_config_*.txt

# Сброс правил firewall
ufw --force reset

# Очистка зависимостей
apt-get autoremove -y
apt-get clean

echo -e "\e[1;32m[✔️] Все компоненты SMTP-сервера были полностью удалены\e[0m"
