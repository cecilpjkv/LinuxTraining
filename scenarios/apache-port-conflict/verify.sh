sleep 1  # a graceful reload lets old workers answer for a moment
site_ok() {  # site_ok CHECK HOST PATH TEXT
  local code body
  code=$(curl -s -o /tmp/.lt-body -m 10 -w '%{http_code}' -H "Host: $2" "http://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for http://$2$3"; fi
}
check httpd_running systemctl is-active --quiet httpd
check httpd_enabled systemctl is-enabled --quiet httpd
ss -ltnp | grep -E '[:.]80 ' | grep -q httpd && ! ss -ltnp | grep -E '[:.]80 ' | grep -q nginx && pass port_owner || fail port_owner "port 80 is not served by Apache alone"
srv=$(curl -sI -m 5 -H 'Host: portal.example.test' http://127.0.0.1/ | sed -n 's/^Server: //Ip' | tr -d '\r')
case "$srv" in Apache*) site_ok portal_works portal.example.test / 'Portal OK';; *) fail portal_works "answered by '$srv'";; esac
if systemctl is-enabled --quiet nginx 2>/dev/null && nginx -T 2>/dev/null | grep -Eq '^\s*listen\s+(\[::\]:)?80([ ;]|$)'; then
  fail no_conflict_at_boot "nginx would take port 80 again at boot"
else
  pass no_conflict_at_boot
fi
