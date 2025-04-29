  **AKUMA Fishing Framework - 悪魔のフィッシングシステム**  

**"In the neon abyss of cyberspace, AKUMA crafts deception with surgical precision..."**  

🚀 **概要 (Overview)**  

AKUMA Fishing Framework — это мощный инструмент для развертывания фишинговых кампаний, сочетающий в себе **Gophish** для управления атаками и **SMTP-сервер** для доставки писем.  
Идеально подходит для **Red Team, пентестов и обучения кибербезопасности**.  

---

   **🔥 特徴 (Features)**  

    **1. Двойная архитектура**  
- **Вариант 1:** Развертывание **Gophish + SMTP на одном хосте** (быстро, для тестов).  
- **Вариант 2:** Раздельное развертывание **Gophish на одном сервере, SMTP на другом** (масштабируемость, стойкость к блокировкам).  

    **2. Автоматизированная установка**  
- **SMTP-сервер** (`setup-smtp-full.sh`):  
  - Postfix + OpenDKIM + Let's Encrypt SSL  
  - Автогенерация DNS-записей (SPF, DKIM, DMARC)  
  - Поддержка TLS для безопасной отправки  
- **Gophish** (`install-gophish.sh`):  
  - Установка из исходников  
  - Генерация самоподписанных SSL-сертификатов  
  - Настройка systemd для автозапуска  

    **3. Устойчивость к блокировкам**  
- **Ротация IP/DNS** (через Cloudflare API, если настроено)  
- **Мониторинг доступности** (автопереключение на резервные SMTP)  

    **4. Интеграция с инфраструктурой**  
- Поддержка **Proxmox/KVM** для быстрого развертывания виртуальных машин  
- **API-доступ** к Gophish для автоматизации кампаний  

---

   **⚡ 起動コマンド (Activation Sequence)**  

    **1. Вариант: Gophish + SMTP на одном хосте**  
``` 
  Установка SMTP-сервера
chmod +x setup-smtp-full.sh
sudo ./setup-smtp-full.sh -d evil.com -u phishing_user

  Установка Gophish
chmod +x install-gophish.sh
sudo ./install-gophish.sh -d evil.com -a 3333 -p 80 -i 0.0.0.0
```

    **2. Вариант: Раздельное развертывание**  
     **На SMTP-сервере:**  
``` 
chmod +x setup-smtp-full.sh
sudo ./setup-smtp-full.sh -d evil.com -u smtp_user
```  
     **На Gophish-сервере:**  
``` 
chmod +x install-gophish.sh
sudo ./install-gophish.sh -d evil.com -a 3333 -p 80 -i 0.0.0.0
```  
После установки **настроить SMTP в Gophish**:  
```
SMTP Server: mail.evil.com  
Port: 587  
Use TLS: ✅  
Username: smtp_user  
Password: [из файла /root/smtp_config_evil.com.txt]  
```

---

   **🌌 出力例 (Sample Output)**  

    **SMTP-сервер (`setup-smtp-full.sh`)**  
```
╔══════════════════════════════════════════╗
║           SMTP КОНФИГУРАЦИЯ             ║
╠══════════════════════════════════════════╣
║  Домен:          evil.com
║  Хост:           mail.evil.com
║  Пользователь:   smtp_user
║  Пароль:         Jx8 kLm2!pQ9
║  SMTP Порт:      587 (STARTTLS)
╚══════════════════════════════════════════╝
```  

    **Gophish (`install-gophish.sh`)**  
```
╔══════════════════════════════════════════╗
║            Gophish Конфигурация          ║
╠══════════════════════════════════════════╣
║  Админ панель: https://0.0.0.0:3333
║  Логин: admin
║  Пароль: dR5@kP9!qW2
║  Фишинг порт: 80
╚══════════════════════════════════════════╝
```  

---

   **💀 システム要件 (System Requirements)**  
    **地獄の依存関係 (Dependencies from Hell)**  
``` 
sudo apt update && sudo apt install -y git golang postfix opendkim certbot
```  

---

   **⚠️ 免責事項 (Disclaimer)**  
**Этот инструмент предназначен только для:**  
✅ Законного тестирования безопасности  
✅ Обучения сотрудников  
✅ Red Team операций **с разрешения**  

*"The demon bites both ways — use responsibly."*  

---

   **🌐 Github & License**  
**Repository:** [https://github.com/sweetpotatohack/Fishing_AKUMA_evil.com](https://github.com/sweetpotatohack/Fishing_AKUMA_evil.com)  
**License:** **BSD 3-Clause "New" or "Revised" License** (血の誓約)  

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
