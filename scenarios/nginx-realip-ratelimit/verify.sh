sleep 1  # a graceful reload lets old workers answer for a moment
site_ok() {  # site_ok CHECK HOST PATH TEXT [scheme]
  local code
  code=$(curl -sk -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "${5:-http}://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for ${5:-http}://$2$3"; fi
}
ok=0; for i in $(seq 1 30); do [ "$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: shop.example.test' -H "X-Forwarded-For: 198.51.100.$i" http://127.0.0.1/)" = 200 ] && ok=$((ok+1)); done
[ "$ok" -eq 30 ] && pass customers_separate "30/30 different customers served" || fail customers_separate "$ok/30 different customers served"
sleep 2; bad=0; for i in $(seq 1 30); do [ "$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: shop.example.test' -H 'X-Forwarded-For: 203.0.113.9' http://127.0.0.1/)" = 503 ] && bad=$((bad+1)); done
[ "$bad" -ge 10 ] && pass flood_limited "$bad/30 refused" || fail flood_limited "a flooding client got only $bad/30 refusals"
check config_valid nginx -t
