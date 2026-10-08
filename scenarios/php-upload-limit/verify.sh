sleep 3  # graceful reloads answer with the old config for a moment; opcache re-reads changed files every 2 s
site_ok() {  # site_ok CHECK HOST PATH TEXT
  local code
  code=$(curl -s -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "http://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for http://$2$3"; fi
}
head -c 5000000 /dev/urandom > /tmp/.lt-upload.bin
out=$(curl -s -m 30 -H 'Host: shop.example.test' -F "file=@/tmp/.lt-upload.bin" http://127.0.0.1/upload.php)
case "$out" in "UPLOAD OK 5000000"*) pass upload_5mb;; *) fail upload_5mb "$(printf '%s' "$out" | head -c 150)";; esac
check fpm_running systemctl is-active --quiet php-fpm
check config_valid nginx -t
site_ok shop_works shop.example.test / 'PHP-OK-42'
