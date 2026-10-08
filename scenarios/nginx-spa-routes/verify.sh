sleep 1  # a graceful reload lets old workers answer for a moment
site_ok() {  # site_ok CHECK HOST PATH TEXT [scheme]
  local code
  code=$(curl -sk -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "${5:-http}://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for ${5:-http}://$2$3"; fi
}
site_ok deep_link shop.example.test /products/42 'SPA-SHELL'
site_ok home shop.example.test / 'SPA-SHELL'
site_ok assets shop.example.test /assets/app.js 'APP-JS'
c=$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: shop.example.test' http://127.0.0.1/assets/missing.js)
[ "$c" = 404 ] && pass missing_asset_404 || fail missing_asset_404 "missing asset answered $c"
