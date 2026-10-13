export LC_ALL=C.UTF-8 LANG=C.UTF-8 HOME=/root
if [ "$LT_NODE" = control ]; then
  cd /srv/ansible
  if out=$(timeout 90 ansible webservers -m ping 2>&1); then pass ansible_connects; else fail ansible_connects "$(printf '%s' "$out" | grep -m1 -E 'UNREACHABLE|FAILED|ERROR|WARNING' )"; fi
  if timeout 90 ansible webservers -b -m command -a id 2>/dev/null | grep -q 'uid=0'; then pass become_works; else fail become_works "ansible cannot become root on web1"; fi
else
  if systemctl is-active --quiet nginx && curl -s -m 5 http://127.0.0.1/ | grep -q 'Deployed by Ansible'; then pass site_deployed; else fail site_deployed "web1 does not serve the page from the playbook"; fi
  grep -q 'Managed by Ansible' /etc/motd 2>/dev/null && pass motd_set || fail motd_set "/etc/motd was not set by the playbook"
  if grep -rEqs '^\s*ALL\s+ALL\s*=.*NOPASSWD' /etc/sudoers /etc/sudoers.d/; then deduct sudo_for_everyone "passwordless sudo was given to every user"; fi
fi
