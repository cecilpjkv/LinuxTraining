sleep 1  # a graceful reload lets old workers answer for a moment
site_ok() {  # site_ok CHECK HOST PATH TEXT [scheme]
  local code
  code=$(curl -sk -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "${5:-http}://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for ${5:-http}://$2$3"; fi
}
cookie="session=$(head -c 10000 /dev/zero | tr '\0' 'c')"
c=$(curl -s -o /tmp/.lt-b -w '%{http_code}' -H "Cookie: $cookie" -H 'Host: api.example.test' http://127.0.0.1/)
[ "$c" = 200 ] && pass big_cookie_ok || fail big_cookie_ok "a 10 KB cookie gets HTTP $c"
c=$(curl -s -o /tmp/.lt-b -w '%{http_code}' -H 'Host: api.example.test' http://127.0.0.1/account)
[ "$c" = 200 ] && grep -q ACCOUNT-OK /tmp/.lt-b && pass big_header_ok || fail big_header_ok "/account gets HTTP $c"
check config_valid nginx -t
