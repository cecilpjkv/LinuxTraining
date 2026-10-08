sleep 1  # a graceful reload lets old workers answer for a moment
site_ok() {  # site_ok CHECK HOST PATH TEXT [scheme]
  local code
  code=$(curl -sk -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "${5:-http}://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for ${5:-http}://$2$3"; fi
}
check config_valid nginx -t
check nginx_running systemctl is-active --quiet nginx
site_ok shop_works shop.example.test / 'Shop OK'
ps -o user= -C nginx | grep -vq root && ! ps -o user= -C nginx | grep -v root | grep -qx root && pass workers_unprivileged || fail workers_unprivileged "nginx workers run as root"
