sleep 1  # a graceful reload lets old workers answer for a moment
site_ok() {  # site_ok CHECK HOST PATH TEXT [scheme]
  local code
  code=$(curl -sk -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "${5:-http}://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for ${5:-http}://$2$3"; fi
}
c=$(curl -s -o /tmp/.lt-a -w '%{http_code}' -u staff:Staff-Pass-1 -H 'Host: shop.example.test' http://127.0.0.1/admin/)
[ "$c" = 200 ] && grep -q ADMIN-AREA /tmp/.lt-a && pass staff_access || fail staff_access "staff gets HTTP $c"
c=$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: shop.example.test' http://127.0.0.1/admin/)
[ "$c" = 401 ] && pass still_protected || fail still_protected "without a password: HTTP $c"
m=$(stat -c %a /etc/nginx/.htpasswd); [ $(( 0$m & 07 )) -eq 0 ] && pass file_private "mode $m" || fail file_private "readable by everybody ($m)"
