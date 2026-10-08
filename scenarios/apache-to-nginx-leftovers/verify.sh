sleep 3  # graceful reloads answer with the old config for a moment; opcache re-reads files every 2 s
site_ok() {  # site_ok CHECK HOST PATH TEXT [scheme]
  local code
  code=$(curl -sk -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "${5:-http}://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for ${5:-http}://$2$3"; fi
}
srv=$(curl -sI -m 5 -H 'Host: shop.example.test' http://127.0.0.1/ | sed -n 's/^Server: //Ip' | tr -d '\r')
case "$srv" in nginx*) pass served_by_nginx "$srv";; *) fail served_by_nginx "answered by '$srv'";; esac
site_ok php_runs shop.example.test / 'PHP-OK-42'
site_ok catalog_works shop.example.test /catalog/ 'CATALOG-OK'
curl -s -m 5 -H 'Host: shop.example.test' http://127.0.0.1/settings.php | grep -q 'Leaked-Key' && fail no_source_exposed "PHP source is downloadable" || pass no_source_exposed
if systemctl is-enabled --quiet httpd 2>/dev/null || systemctl is-active --quiet httpd; then fail apache_off "Apache is still enabled or running"; else pass apache_off; fi
