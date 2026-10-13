#!/bin/bash
set -e
if [ "$LT_NODE" = web1 ]; then
  rm -f /etc/ssh/sshd_config.d/*permitrootlogin*.conf
  id ansible >/dev/null 2>&1 || useradd -m -s /bin/bash ansible
  k=$(mktemp -d)
  ssh-keygen -q -t ed25519 -N '' -C 'ansible@control' -f $k/key
  install -d -m 700 -o ansible -g ansible /home/ansible/.ssh
  install -m 600 -o ansible -g ansible $k/key.pub /home/ansible/.ssh/authorized_keys
  echo "@@LT SHARE ANSIBLE_KEY $(base64 -w0 < $k/key)"
  rm -rf $k
  # sudo for the automation user (asks for a password the account does not have)
  echo 'ansible ALL=(ALL) ALL' > /etc/sudoers.d/ansible
  chmod 440 /etc/sudoers.d/ansible
  echo '<h1>Welcome to nginx</h1>' > /usr/share/nginx/html/index.html
  systemctl enable sshd && systemctl restart sshd
else
  install -d -m 700 /root/.ssh
  printf '%s' "$LT_SHARE_ANSIBLE_KEY" | base64 -d > /root/.ssh/ansible_ed25519
  chmod 600 /root/.ssh/ansible_ed25519
  mkdir -p /srv/ansible
  cat > /srv/ansible/ansible.cfg <<'CFG'
[defaults]
inventory = inventory.ini
remote_user = ansible
private_key_file = /root/.ssh/id_ansible
host_key_checking = False
retry_files_enabled = False
interpreter_python = auto_silent
CFG
  cat > /srv/ansible/inventory.ini <<'INV'
# web servers
[webservers]
web1.example.lan
INV
  cat > /srv/ansible/site.yml <<'YML'
- name: Web servers
  hosts: webservers
  become: true
  tasks:
    - name: Site content
      ansible.builtin.copy:
        dest: /usr/share/nginx/html/index.html
        content: "<h1>Northwind</h1><p>Deployed by Ansible</p>\n"
    - name: Message of the day
      ansible.builtin.copy:
        dest: /etc/motd
        content: "Managed by Ansible - local changes will be overwritten\n"
    - name: nginx is running
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true
YML
fi
