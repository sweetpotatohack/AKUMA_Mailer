  **AKUMA Fishing Framework - 悪魔のフィッシングシステム**  

**"In the neon abyss of cyberspace, AKUMA crafts deception with surgical precision..."**  

🚀 **概要 (Overview)**  

AKUMA Fishing Framework — это мощный инструмент для развертывания фишинговых кампаний, сочетающий в себе **Gophish** для управления атаками и **SMTP-сервер** для доставки писем.  
Идеально подходит для **Red Team, пентестов и обучения кибербезопасности**.  
Скрипты предназначены для автоматического развертывания фишинговой платформы GoPhish с поддержкой TLS и полноценного SMTP-сервера с DKIM, SPF, и DMARC для домена `AKUMA.fun`.

---

# ☠️ GoPhish + SMTP Авторазвертывание (AKUMA.fun)

Данный репозиторий содержит два скрипта для автоматического развертывания:
- `setup-GoFish-full.sh` — установка и настройка GoPhish с поддержкой HTTPS.
- `setup-smtp-full.sh` — автоматическая установка SMTP-сервера с поддержкой DKIM/SPF/DMARC.

---

## 📁 Содержимое

| Скрипт | Назначение |
|--------|------------|
| `setup-GoFish-full.sh` | Автоматическая установка GoPhish, генерация TLS-сертификатов Let's Encrypt, настройка конфигурации и запуск |
| `setup-smtp-full.sh` | Полноценный SMTP-сервер с Postfix + Dovecot + DKIM/SPF/DMARC + TLS. Генерация пользователя и вывод DNS-записей |

---

## 🐟 Установка GoPhish (`setup-GoFish-full.sh`)

### 🔧 Возможности:
- Проверка и освобождение портов 80 и 3333.
- Автоматическая установка Certbot и получение TLS-сертификатов.
- Скачивание и настройка GoPhish.
- Запуск GoPhish в фоне (порт 3333).
- Настройка автопродления сертификатов через cron.

### 📌 Требования:
- Домен (пример: `fish.AKUMA.fun`)
- Открытые порты: `80`, `443`, `3333`
- Установленный `certbot`, `wget`, `unzip`, `lsof`

### ▶️ Команда запуска:
```bash
sudo bash setup-GoFish-full.sh
```

---

## 📬 Установка SMTP-сервера (`setup-smtp-full.sh`)

### 🔧 Возможности:
- Полная установка SMTP-сервера (Postfix + Dovecot).
- Поддержка STARTTLS (порт 587).
- Автоматическая генерация DKIM ключей.
- Настройка SPF, DKIM, DMARC.
- Получение Let's Encrypt сертификата.
- Создание почтового пользователя и Maildir.
- Сохранение конфигурации и рекомендаций по DNS в текстовый файл.
- Поддержка автопродления сертификатов.

### 📌 Требования:
- Домен (пример: `AKUMA.fun`)
- Открытые порты: `587`, `143`, `993`, `80`, `443`
- DNS A-запись: `mail.AKUMA.fun` → ваш сервер

### ▶️ Команда запуска:
```bash
sudo bash setup-smtp-full.sh -d AKUMA.fun -u your_smtp_user
```

Если не указать аргументы:
- домен по умолчанию: `example.com`
- пользователь по умолчанию: `smtp_user`

### 📤 Пример отправки письма:
```bash
swaks --to test@AKUMA.fun --from test@AKUMA.fun \
  --server mail.AKUMA.fun \
  --auth LOGIN \
  --auth-user your_smtp_user \
  --auth-password 'сгенерированный_пароль' \
  --tls
```

---

## 🛠️ DNS-записи (пример для AKUMA.fun)

| Тип | Имя | Значение |
|-----|-----|----------|
| A   | mail(subdomain)         | `YOUR_SERVER_IP` |
| MX  | @            | `mail.AKUMA.fun (priority 10)` |
| TXT | @ (SPF)      | `"v=spf1 mx a ip4:YOUR_SERVER_IP ~all"` |
| TXT | mail._domainkey | `DKIM public key (генерируется)` |
| TXT | _dmarc       | `"v=DMARC1; p=none; rua=mailto:dmarc@AKUMA.fun"` |

---

## ⚠️ Важно
- Убедитесь, что все необходимые порты открыты в фаерволе.
- После установки обязательно проверьте корректность DNS-записей.
- Не запускайте эти скрипты на продуктивных почтовых серверах без разбора их содержимого.

---

## 💀 Автор
Проект разработан для домена `AKUMA.fun` и ориентирован на автоматизацию развертывания фишинговой платформы и SMTP-сервера в рамках тестирования и демонстрационных целей.

```
          _  _                  _  _            
         / \/ \   _   _   _   / \/ \    _   _  
        / /\_/\ / \ / \ / \ / /\_/\ \ / \ / \ 
        \/      \_/ \_/ \_/ \/      \/ \_/ \_/ 
        悪魔はフィッシングを見る...
```  

**"Exploit like water, crash like a wave."**  
**"A single phishing link can topple empires."**  
**"Patches are temporary. Social engineering is eternal."**

LICENSE - https://github.com/sweetpotatohack/Fishing_AKUMA_evil.com/blob/main/LICENSE
