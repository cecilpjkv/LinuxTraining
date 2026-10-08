sleep 3  # graceful reloads answer with the old config for a moment; opcache re-reads changed files every 2 s
site_ok() {  # site_ok CHECK HOST PATH TEXT
  local code
  code=$(curl -s -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "http://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for http://$2$3"; fi
}
site_ok shop_works shop.example.test / 'EXAMPLE SHOP ÜNÏCODE'
php -m 2>/dev/null | grep -qx mbstring && pass extension_installed || fail extension_installed "mbstring is not loaded"
sha256sum -c --quiet /root/.lt-code.sha256 >/dev/null 2>&1 && pass code_unchanged || fail code_unchanged "the shop's code was changed"
