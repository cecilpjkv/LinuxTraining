sleep 1  # a graceful reload lets old workers answer for a moment
site_ok() {  # site_ok CHECK HOST PATH TEXT
  local code body
  code=$(curl -s -o /tmp/.lt-body -m 10 -w '%{http_code}' -H "Host: $2" "http://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for http://$2$3"; fi
}
site_ok home_page shop.example.test / 'Shop OK'
site_ok logo shop.example.test /img/logo.png 'PNG-LOGO'
check config_valid nginx -t
