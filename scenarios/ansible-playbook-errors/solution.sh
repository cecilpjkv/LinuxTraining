# reference fix (not imported; used by scripts/check_scenarios.py): runs on every server, web1 first
export LC_ALL=C.UTF-8 LANG=C.UTF-8 HOME=/root
[ "$LT_NODE" = control ] || exit 0
cd /srv/ansible
mv group_vars/webserver.yml group_vars/webservers.yml
sed -i 's/^   notify: reload nginx/  notify: reload nginx/' roles/intranet/tasks/main.yml
sed -i 's/^- name: Reload Nginx/- name: reload nginx/' roles/intranet/handlers/main.yml
ansible-playbook site.yml </dev/null >/tmp/play.log 2>&1 || { tail -20 /tmp/play.log; exit 1; }
