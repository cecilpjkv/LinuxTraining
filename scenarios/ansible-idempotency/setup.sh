#!/bin/bash
set -e
export LC_ALL=C.UTF-8 LANG=C.UTF-8 HOME=/root
rm -f /etc/ssh/sshd_config.d/*permitrootlogin*.conf
systemctl enable sshd && systemctl restart sshd
mkdir -p /srv/ansible
cat > /srv/ansible/hardening.yml <<'YML'
- name: Server hardening
  hosts: localhost
  connection: local
  tasks:
    - name: SSH hardening settings
      ansible.builtin.shell: |
        echo "MaxAuthTries 3" >> /etc/ssh/sshd_config.d/50-hardening.conf
        echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config.d/50-hardening.conf
        echo "X11Forwarding no" >> /etc/ssh/sshd_config.d/50-hardening.conf

    - name: Deploy user
      ansible.builtin.command: useradd -m -s /bin/bash deploy

    - name: Restart sshd
      ansible.builtin.command: systemctl restart sshd

    - name: Login banner
      ansible.builtin.shell: echo "Authorized use only. Activity is logged." >> /etc/issue.net
YML
cd /srv/ansible
ansible-playbook hardening.yml </dev/null >/dev/null 2>&1
ansible-playbook hardening.yml </dev/null >/dev/null 2>&1 || true
