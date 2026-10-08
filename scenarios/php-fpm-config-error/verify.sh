sleep 3  # graceful reloads answer with the old config for a moment; opcache re-reads changed files every 2 s
site_ok() {  # site_ok CHECK HOST PATH TEXT
  local code
  code=$(curl -s -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "http://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for http://$2$3"; fi
}
check config_valid php-fpm -t
check fpm_running systemctl is-active --quiet php-fpm
site_ok shop_works shop.example.test / 'PHP-OK-42'
grep -Eq '^pm.max_children = 20\s*$' /etc/php-fpm.d/www.conf && pass capacity_kept || fail capacity_kept "pm.max_children is not 20"
