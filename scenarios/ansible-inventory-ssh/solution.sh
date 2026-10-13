# reference fix (not imported; used by scripts/check_scenarios.py): runs on every server, web1 first
export LC_ALL=C.UTF-8 LANG=C.UTF-8 HOME=/root
if [ "$LT_NODE" = web1 ]; then
  echo 'ansible ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ansible
else
  cd /srv/ansible
  sed -i 's|^private_key_file = .*|private_key_file = /root/.ssh/ansible_ed25519|' ansible.cfg
  sed -i 's/^web1.example.lan$/web1/' inventory.ini
  ansible-playbook site.yml </dev/null >/tmp/play.log 2>&1 || { tail -20 /tmp/play.log; exit 1; }
fi
