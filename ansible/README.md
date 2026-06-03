Установка podkop, sing-box на openwrt 24/25
=========

Requirements
------------

Any pre-requisites that may not be covered by Ansible itself or the role should be mentioned here. For instance, if the role uses the EC2 module, it may be a good idea to mention in this section that the boto package is required.

Role Variables
--------------

A description of the settable variables for this role should go here, including any variables that are in defaults/main.yml, vars/main.yml, and any variables that can/should be set via parameters to the role. Any variables that are read from other roles and/or the global scope (ie. hostvars, group vars, etc.) should be mentioned here as well.

Зависимости
------------

```sh
ssh-keygen -t ed25519 -f ~/.ssh/ 
ssh-copy-id  -i ~/.ssh/id_ed25519.pub -f root@192.168.1.1
ansible-galaxy collection install community.openwrt
```
Примеры
----------------

Проверка доступности instagram с роутера
```sh
ansible-playbook -i inventory check_instagram.yml
```

Обновить podkop на роутере
```sh
ansible-playbook -i inventory install_podkop.yml
```

Обновить sing-box на роутере
```sh
ansible-playbook -i inventory install_singbox.yml
```
