sleep 1  # a graceful reload lets old workers answer for a moment
site_ok() {  # site_ok CHECK HOST PATH TEXT [scheme]
  local code
  code=$(curl -sk -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "${5:-http}://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for ${5:-http}://$2$3"; fi
}
site_ok php_runs portal.example.test /status.php 'PHP-OK-42'
curl -s -m 10 -H 'Host: portal.example.test' http://127.0.0.1/config.php | grep -q 'Portal-DB-Secret' && fail source_hidden "config.php still shows its source" || pass source_hidden
check fpm_enabled systemctl is-enabled --quiet php-fpm
