 Ansible Automation for AKUMA Fishing Infrastructure  
"Where demons play, automation reigns supreme."  

---

 🌑 地獄の自動化 (Hell's Automation)  
Ansible обеспечивает централизованное управление всей фишинговой инфраструктурой:  
- Мастер-хаб → Контроллер Ansible  
- Юниты → Управляемые узлы (Gophish + SMTP)  

---

 ⚡ 1. Ansible Playbook Structure  
```
akuma_fishing/  
├── inventories/  
│   ├── production/  
│   │   ├── hosts.yml        Группы юнитов  
│   │   └── vars.yml         Глобальные переменные  
│   └── testing/             Тестовая среда  
├── roles/  
│   ├── smtp_server/         Установка Postfix+OpenDKIM  
│   ├── gophish/             Развертывание Gophish  
│   ├── monitoring/          Настройка Prometheus/Zabbix  
│   └── wireguard/           VPN для юнитов  
├── templates/               Jinja2 шаблоны  
├── scripts/                 Вспомогательные скрипты  
└── playbooks/  
    ├── deploy_smtp.yml      Развертывание SMTP  
    ├── deploy_gophish.yml   Развертывание Gophish  
    └── rotate_resources.yml  Ротация IP/доменов  
```

---

 🔥 2. Key Playbooks  

 🔹 1. `deploy_smtp.yml`  
```
- name: Deploy SMTP Server  
  hosts: smtp_servers  
  become: true  
  roles:  
    - role: smtp_server  
      vars:  
        domain: "{{ fishing_domain }}"  
        smtp_user: "phishmaster"  
        dkim_selector: "mail"  
```  
Функции:  
- Устанавливает Postfix + OpenDKIM  
- Генерирует DKIM/SPF/DMARC записи  
- Настраивает TLS через Let's Encrypt  

---

 🔹 2. `deploy_gophish.yml`  
```
- name: Deploy Gophish  
  hosts: fishing_units  
  become: true  
  roles:  
    - role: gophish  
      vars:  
        admin_port: 3333  
        phishing_port: 80  
        smtp_server: "smtp.{{ fishing_domain }}"  
        smtp_credentials:  
          user: "{{ vault_smtp_user }}"  
          pass: "{{ vault_smtp_pass }}"  
```  
Функции:  
- Собирает Gophish из исходников  
- Настраивает systemd service  
- Интегрируется с SMTP (credentials в Ansible Vault)  

---

 🔹 3. `rotate_resources.yml`  
```
- name: Rotate IPs/Domains  
  hosts: fishing_units  
  tasks:  
    - name: Change IP via Proxmox API  
      uri:  
        url: "https://proxmox/api2/json/nodes/{{ node }}/qemu/{{ vmid }}/config"  
        method: POST  
        headers:  
          Authorization: "PVEAPIToken={{ api_token }}"  
        body:  
          ipconfig0: "ip={{ new_ip }}/24,gw={{ gateway }}"  
      delegate_to: master_hub  
      when: block_detected.rc == 1   Если мониторинг обнаружил блокировку  
```  
Функции:  
- Автоматическая смена IP через Proxmox API  
- Обновление DNS записей (Cloudflare/Namecheap API)  

---

 🌑 3. Inventory Example (`hosts.yml`)  
```
all:  
  children:  
    master_hub:  
      hosts:  
        192.168.1.100:  
    smtp_servers:  
      hosts:  
        192.168.1.101:  
    fishing_units:  
      hosts:  
        192.168.1.102:  
        192.168.1.103:  
      vars:  
        ansible_user: "akuma"  
        ansible_ssh_private_key_file: "~/.ssh/akuma_key"  
```

---

 💀 4. Security with Ansible Vault  
Шифрование SMTP/Gophish credentials:  
```
ansible-vault encrypt_string 's3cr3t_p@ss' --name 'vault_smtp_pass'  
```  
Использование в playbook:  
```
vars_files:  
  - secrets.yml   Зашифровано через ansible-vault  
```

---

 ⚡ 5. Monitoring Integration  
Prometheus + Grafana:  
```
- name: Deploy Monitoring  
  hosts: master_hub  
  roles:  
    - role: monitoring  
      vars:  
        targets:  
          - "{{ groups.fishing_units }}"  
        alerts:  
          phishing_page_down:  
            expr: 'up{job="gophish"} == 0'  
```  
Дашборды:  
- Статус юнитов  
- SMTP-статистика (отправлено/доставлено)  
- DNS-блокировки  

---

 🚀 6. Proxmox Automation  
Создание VM из шаблона:  
```
- name: Clone VM Template  
  hosts: proxmox  
  tasks:  
    - community.general.proxmox_kvm:  
        api_user: "root@pam"  
        api_password: "{{ vault_proxmox_pass }}"  
        clone: "gophish-template"  
        newid: 101  
        name: "unit-01"  
        node: "pve"  
```

---

 🌌 7. Full Deployment Workflow  
1. Инициализация инфраструктуры:  
   ```
   ansible-playbook -i inventories/production playbooks/provision_vms.yml  
   ```  
2. Развертывание SMTP:  
   ```
   ansible-playbook -i inventories/production playbooks/deploy_smtp.yml  
   ```  
3. Развертывание Gophish:  
   ```
   ansible-playbook -i inventories/production playbooks/deploy_gophish.yml  
   ```  
4. Мониторинг:  
   ```
   ansible-playbook -i inventories/production playbooks/deploy_monitoring.yml  
   ```  

---

 ⚠️ 免責事項 (Disclaimer)  
- Используйте только для легального тестирования.  
- Все credentials хранятся в Ansible Vault.  
- Ротация IP/DNS требует API-доступа к провайдеру.  

```
          _  _                  _  _            
         / \/ \   _   _   _   / \/ \    _   _  
        / /\_/\ / \ / \ / \ / /\_/\ \ / \ / \ 
        \/      \_/ \_/ \_/ \/      \/ \_/ \_/ 
        自動化された悪魔...
```  
"When automation meets chaos, even shadows tremble."  

Github: [https://github.com/sweetpotatohack/Fishing_AKUMA_evil.com](https://github.com/sweetpotatohack/Fishing_AKUMA_evil.com)  
License: BSD 3-Clause "New" or "Revised" License

 Пошаговая инструкция по автоматизации фишинговой инфраструктуры с Ansible

 🔰 1. Подготовка мастер-хаба (Ansible Control Node)
Требования:
- Ubuntu/Debian на мастер-хабе
- Доступ к Proxmox API (если используется автоматическое развертывание VM)
- SSH-доступ к юнитам

 1.1. Установка Ansible
```
sudo apt update
sudo apt install -y ansible git python3-pip
pip3 install proxmoxer requests   Для работы с Proxmox API
```

 1.2. Настройка SSH-ключей
```
ssh-keygen -t ed25519 -f ~/.ssh/akuma_key   Генерация ключа
cat ~/.ssh/akuma_key.pub | ssh root@юнит "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

---

 📁 2. Структура проекта Ansible
```
mkdir -p ~/akuma_fishing/{inventories,roles,playbooks,templates,scripts}
cd ~/akuma_fishing
```

 2.1. Inventory-файл (`inventories/production/hosts.yml`)
```
all:
  children:
    master_hub:
      hosts:
        192.168.1.100:
    smtp_servers:
      hosts:
        192.168.1.101:
    fishing_units:
      hosts:
        192.168.1.102:
        192.168.1.103:
      vars:
        ansible_user: "root"
        ansible_ssh_private_key_file: "~/.ssh/akuma_key"
```

 2.2. Глобальные переменные (`inventories/production/group_vars/all.yml`)
```
---
fishing_domain: "evil.com"
smtp_user: "phishmaster"
dkim_selector: "mail"
```

---

 🎭 3. Создание Ansible Roles

 3.1. Роль для SMTP-сервера
```
ansible-galaxy init roles/smtp_server
```

 `roles/smtp_server/tasks/main.yml`
```
- name: Install dependencies
  apt:
    name: ["postfix", "opendkim", "certbot", "mailutils"]
    state: present

- name: Configure Postfix
  template:
    src: templates/postfix_main.cf.j2
    dest: /etc/postfix/main.cf

- name: Generate DKIM keys
  command: "opendkim-genkey -s {{ dkim_selector }} -d {{ fishing_domain }}"
  args:
    chdir: "/etc/opendkim/keys/{{ fishing_domain }}"
    creates: "/etc/opendkim/keys/{{ fishing_domain }}/{{ dkim_selector }}.private"
```

 Шаблон Postfix (`roles/smtp_server/templates/postfix_main.cf.j2`)
```jinja
myhostname = mail.{{ fishing_domain }}
mydomain = {{ fishing_domain }}
inet_interfaces = all
```

---

 3.2. Роль для Gophish
```
ansible-galaxy init roles/gophish
```

 `roles/gophish/tasks/main.yml`
```
- name: Install Golang
  apt:
    name: golang
    state: present

- name: Clone Gophish
  git:
    repo: "https://github.com/gophish/gophish.git"
    dest: "/opt/gophish"

- name: Build Gophish
  command: go build
  args:
    chdir: "/opt/gophish"

- name: Configure Gophish
  template:
    src: templates/config.json.j2
    dest: "/opt/gophish/config.json"
```

---

 🚀 4. Playbooks

 4.1. Развертывание SMTP (`playbooks/deploy_smtp.yml`)
```
- name: Deploy SMTP Infrastructure
  hosts: smtp_servers
  become: true
  roles:
    - smtp_server
```

 4.2. Развертывание Gophish (`playbooks/deploy_gophish.yml`)
```
- name: Deploy Gophish Units
  hosts: fishing_units
  become: true
  roles:
    - gophish
```

---

 🔐 5. Шифрование секретов с Ansible Vault
```
ansible-vault create inventories/production/vault.yml
```
Содержимое:
```
vault_smtp_pass: "s3cr3t_p@ssw0rd"
vault_proxmox_token: "your-api-token"
```

Использование в playbook:
```
- name: Example with Vault
  hosts: all
  vars_files:
    - inventories/production/vault.yml
  tasks:
    - debug:
        msg: "SMTP password is {{ vault_smtp_pass }}"
```

---

 ⚡ 6. Запуск автоматизации
```
 Развертывание SMTP
ansible-playbook -i inventories/production/hosts.yml playbooks/deploy_smtp.yml --ask-vault-pass

 Развертывание Gophish
ansible-playbook -i inventories/production/hosts.yml playbooks/deploy_gophish.yml
```

---

 📊 7. Мониторинг и ротация
 7.1. Playbook для ротации IP (`playbooks/rotate_ips.yml`)
```
- name: Rotate IPs for blocked units
  hosts: fishing_units
  tasks:
    - name: Change IP via Proxmox API
      uri:
        url: "https://proxmox/api2/json/nodes/{{ node }}/qemu/{{ vmid }}/config"
        method: POST
        headers:
          Authorization: "PVEAPIToken={{ vault_proxmox_token }}"
        body:
          ipconfig0: "ip={{ new_ip }}/24,gw={{ gateway }}"
      when: block_detected.rc == 1
```

 7.2. Крон для автоматической проверки
```
crontab -e
```
Добавить:
```
0     ansible-playbook -i ~/akuma_fishing/inventories/production/hosts.yml ~/akuma_fishing/playbooks/rotate_ips.yml --ask-vault-pass
```

---

 💀 Итоговая архитектура
```
Мастер-хаб (Ansible)
├── SMTP-сервер (Postfix + OpenDKIM)
└── Юниты Gophish
    ├── Unit 1 (192.168.1.102)
    └── Unit 2 (192.168.1.103)
```

Команда для полного развертывания:
```
ansible-playbook -i inventories/production/hosts.yml playbooks/deploy_all.yml --ask-vault-pass
```

---
```
          _  _                  _  _            
         / \/ \   _   _   _   / \/ \    _   _  
        / /\_/\ / \ / \ / \ / /\_/\ \ / \ / \ 
        \/      \_/ \_/ \_/ \/      \/ \_/ \_/ 
        Ансибл-демон активирован...
```
"Automation is the demon's whisper in the infrastructure's ear."  

Github: [https://github.com/sweetpotatohack/Fishing_AKUMA_evil.com](https://github.com/sweetpotatohack/Fishing_AKUMA_evil.com)  
License: BSD 3-Clause "New" or "Revised" License
