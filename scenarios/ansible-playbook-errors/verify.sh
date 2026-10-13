export LC_ALL=C.UTF-8 LANG=C.UTF-8 HOME=/root
if [ "$LT_NODE" = control ]; then
  cd /srv/ansible
  if out=$(ansible-playbook --syntax-check site.yml 2>&1); then pass syntax_ok; else fail syntax_ok "$(printf '%s' "$out" | grep -m1 -i error)"; fi
  out=$(timeout 150 ansible-playbook site.yml </dev/null 2>&1); rc=$?
  recap=$(printf '%s' "$out" | grep -E '^web1\s*:')
  if [ $rc -eq 0 ] && printf '%s' "$recap" | grep -q 'changed=0 ' && printf '%s' "$recap" | grep -q 'failed=0 '; then pass idempotent; else fail idempotent "run: rc $rc ${recap:-$(printf '%s' "$out" | grep -m1 -E 'ERROR|fatal')}"; fi
else
  sleep 1
  if curl -s -m 5 http://127.0.0.1:8080/ | grep -q '<h1>Northwind Intranet</h1>'; then pass intranet_served; else fail intranet_served "web1 does not serve the intranet title on port 8080"; fi
  if nginx -t >/dev/null 2>&1 && systemctl is-active --quiet nginx; then pass nginx_ok; else fail nginx_ok "nginx is not running with a valid configuration"; fi
fi
