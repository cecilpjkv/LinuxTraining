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
  echo 'ansible ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ansible
  chmod 440 /etc/sudoers.d/ansible
  systemctl enable sshd && systemctl restart sshd
else
  install -d -m 700 /root/.ssh
  printf '%s' "$LT_SHARE_ANSIBLE_KEY" | base64 -d > /root/.ssh/ansible_ed25519
  chmod 600 /root/.ssh/ansible_ed25519
  d=/srv/ansible
  mkdir -p $d/roles/intranet/{tasks,handlers,templates} $d/group_vars
  cat > $d/ansible.cfg <<'CFG'
[defaults]
inventory = inventory.ini
remote_user = ansible
private_key_file = /root/.ssh/ansible_ed25519
host_key_checking = False
retry_files_enabled = False
interpreter_python = auto_silent
CFG
  printf '[webservers]\nweb1\n' > $d/inventory.ini
  cat > $d/site.yml <<'YML'
- name: Intranet
  hosts: webservers
  become: true
  roles:
    - intranet
YML
  cat > $d/group_vars/webserver.yml <<'YML'
site_title: Northwind Intranet
http_port: 8080
YML
  cat > $d/roles/intranet/tasks/main.yml <<'YML'
- name: Site directory
  ansible.builtin.file:
    path: /srv/intranet
    state: directory
    mode: "0755"

- name: Site page
  ansible.builtin.template:
    src: index.html.j2
    dest: /srv/intranet/index.html
    mode: "0644"

- name: nginx site configuration
  ansible.builtin.template:
    src: intranet.conf.j2
    dest: /etc/nginx/conf.d/intranet.conf
    mode: "0644"
   notify: reload nginx

- name: nginx is running
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: true
YML
  cat > $d/roles/intranet/handlers/main.yml <<'YML'
- name: Reload Nginx
  ansible.builtin.service:
    name: nginx
    state: reloaded
YML
  cat > $d/roles/intranet/templates/intranet.conf.j2 <<'J2'
# managed by Ansible
server {
    listen {{ http_port }};
    server_name _;
    root /srv/intranet;
}
J2
  cat > $d/roles/intranet/templates/index.html.j2 <<'J2'
<!doctype html><title>{{ site_title }}</title><h1>{{ site_title }}</h1><p>Managed by Ansible</p>
J2
fi
