sleep 1  # a graceful reload lets old workers answer for a moment
site_ok() {  # site_ok CHECK HOST PATH TEXT [scheme]
  local code
  code=$(curl -sk -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "${5:-http}://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for ${5:-http}://$2$3"; fi
}
site_ok newest_release shop.example.test / 'RELEASE-2024-10-07'
[ -L /srv/www/current ] && [ "$(readlink -f /srv/www/current)" = /srv/www/releases/2024-10-07 ] && pass current_link "current -> 2024-10-07" || fail current_link "current -> $(readlink -f /srv/www/current 2>&1)"
check config_valid nginx -t
