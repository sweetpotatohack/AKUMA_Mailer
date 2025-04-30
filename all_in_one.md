# 🎯 Инфраструктура "всё в одном": SMTP + Gophish
```
**Домен:** `AKUMA.fun`  
**Поддомены:**  
- `fish.AKUMA.fun` – для Gophish  
- `mail.AKUMA.fun` – для SMTP  
```
## 🔧 1. Подготовка сервера
```
**Требования:**  
- Ubuntu/Debian 20.04/22.04  
- 4+ GB RAM, 4 CPU  
- Открытые порты: `80`, `443`, `25`, `587`, `3333`, `22`
```
### 1.1. Обновление системы
```
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget
```

### 1.2. Настройка DNS
Добавьте A-записи:

| Поддомен         | IP              |
|------------------|------------------|
| fish.AKUMA.fun   | 198.46.218.58    |
| mail.AKUMA.fun   | 198.46.218.58    |

---

## 📮 2. Установка SMTP-сервера

### 2.1. Автоматическая установка
```
git clone https://github.com/sweetpotatohack/Fishing_AKUMA_evil.com.git
cd ./Fishing_AKUMA_evil.com
chmod +x setup-*
sudo ./setup-smtp-full.sh -d AKUMA.fun -u smtp_user
```

**Скрипт устанавливает:**
- Postfix + OpenDKIM + Dovecot
- Сертификаты TLS (Let's Encrypt)
- DKIM / SPF / DMARC
- SMTP-пользователя: `smtp_user`

**Вывод скрипта:**  
(см. полный лог в `/root/smtp_config_AKUMA.fun.txt`)

**SMTP Конфигурация:**
```
Домен:        AKUMA.fun
Хост:         mail.AKUMA.fun
Пользователь: smtp_user
Пароль:       TNiQXotz*xfKuU8a
Порт:         587 (STARTTLS)
DKIM селектор: mail
```

**DNS-записи:**(Добавь в dns)
```
A     → mail.AKUMA.fun → 198.46.218.58
MX    → AKUMA.fun → mail.AKUMA.fun (10)
SPF   → "v=spf1 mx a ip4:198.46.218.58 ip6:2a0d:6c2:6:16c:: ~all"
DKIM  → mail._domainkey.AKUMA.fun → "v=DKIM1; p=MIIBIjANBg..."
DMARC → _dmarc.AKUMA.fun → "v=DMARC1; p=none; rua=mailto:dmarc@AKUMA.fun"
```

### 2.2. Проверка SMTP(через 10-30 мину после внесения в dns)
```
dig +short TXT AKUMA.fun
dig +short TXT _dmarc.AKUMA.fun
dig +short TXT mail._domainkey.AKUMA.fun

sudo systemctl status postfix opendkim

swaks --to test@AKUMA.fun --from admin@AKUMA.fun \
--server mail.AKUMA.fun --auth LOGIN \
--auth-user smtp_user --auth-password 'TNiQXotz*xfKuU8a' --tls
```

## 🎣 3. Установка Gophish

**Требования:**  
- Ubuntu/Debian 20.04/22.04  
- Порты: `80`, `443`, `3333`, `22`

### 3.1. Автоматическая установка (перед установкой изменить данные в скрипте 'DOMAIN'+'EMAIL')
DOMAIN="fish.AKUMA.fun"   # ⚠ Укажи свой домен
EMAIL="AKUMA@yandex.ru"   # ⚠ Укажи свой email (для Let's Encrypt)
```
cd /root/Fishing_AKUMA_evil.com
sudo ./setup-Gophish-full.sh
```

**Панель админа:**  
[https://fish.AKUMA.fun:3333/login](https://fish.AKUMA.fun:3333/login)

**Вывод скрипта:**  
- Gophish установлен
- Let's Encrypt сертификат получен
- Gophish работает в фоне
- Доступ: https://fish.AKUMA.fun:3333

### 3.2. Настройка Gophish
Откройте:
```
https://fish.AKUMA.fun:3333
```

**Логин: `admin`  
Пароль:** см. вывод скрипта

**Sending Profile:**
```
SMTP Host: mail.AKUMA.fun
Port: 587
Username: smtp_user
Password: (из SMTP-вывода)
TLS: [✓]
```

---

## 🔒 4. Дополнительные настройки

### 4.1. SSL для Gophish (опционально)
Файл: `/opt/gophish/config.json`  
Замените:
```
"cert_path": "/etc/letsencrypt/live/fish.AKUMA.fun/fullchain.pem",
"key_path": "/etc/letsencrypt/live/fish.AKUMA.fun/privkey.pem"
```

**Перезапуск Gophish:**
```
sudo systemctl stop gophish
sudo rm -rf /opt/gophish /etc/systemd/system/gophish.service
sudo systemctl restart gophish
```

### 4.2. Firewall (если включен)
```
sudo ufw allow 80,443,25,587,3333/tcp
sudo ufw enable
```

---

## 📊 5. Проверка работоспособности

**SMTP:**
```
telnet mail.AKUMA.fun 25
```

**Gophish:**
- Перейдите на `https://fish.AKUMA.fun:3333`
- Создайте кампанию → отправьте письмо → проверьте доставку

```
        _  _                  _  _            
       / \/ \   _   _   _   / \/ \    _   _  
      / /\_/\ / \ / \ / \ / /\_/\ \ / \ / \ 
      \/      \_/ \_/ \_/ \/      \/ \_/ \_/ 
   Фишингинфраструктура готова к атаке!
```

**"The demon feeds on clicks – make them count."**

**GitHub:** [sweetpotatohack/Fishing_AKUMA_evil.com](https://github.com/sweetpotatohack/Fishing_AKUMA_evil.com)  
**Лицензия:** BSD 3-Clause  
```
