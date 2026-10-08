sleep 3  # graceful reloads answer with the old config for a moment; opcache re-reads files every 2 s
site_ok() {  # site_ok CHECK HOST PATH TEXT [scheme]
  local code
  code=$(curl -sk -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "${5:-http}://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for ${5:-http}://$2$3"; fi
}
site_ok php_works portal.example.test /status.php 'PHP-OK-42'
ps -o user= -C php-fpm | grep -qx portal && pass own_pool_user || fail own_pool_user "no PHP-FPM worker runs as portal"
grep -q 'portal.sock' /etc/httpd/conf.d/portal.conf && pass uses_own_pool || fail uses_own_pool "the portal no longer uses its own pool"
[ $(( 0$(stat -c %a /srv/www/portal) & 07 )) -eq 0 ] && pass not_world_readable || fail not_world_readable "the portal files are readable by everybody"
