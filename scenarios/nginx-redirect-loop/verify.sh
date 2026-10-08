sleep 1  # a graceful reload lets old workers answer for a moment
site_ok() {  # site_ok CHECK HOST PATH TEXT [scheme]
  local code
  code=$(curl -sk -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "${5:-http}://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for ${5:-http}://$2$3"; fi
}
site_ok https_works shop.example.test / 'Shop OK' https
loc=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' -H 'Host: shop.example.test' http://127.0.0.1/x?y=1)
case "$loc" in "301 https://shop.example.test/x?y=1"|"308 https://shop.example.test/x?y=1"|"302 https://shop.example.test/x?y=1") pass http_redirects "$loc";; *) fail http_redirects "http answered: $loc";; esac
