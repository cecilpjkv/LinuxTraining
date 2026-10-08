# Final state: configuration valid, nginx running and enabled, the shop page served for its host name.
check nginx_config_valid nginx -t
check nginx_running systemctl is-active --quiet nginx
code=$(http_code -H 'Host: shop.example.test' http://127.0.0.1/)
if [ "$code" = 200 ] && curl -s -m 10 -H 'Host: shop.example.test' http://127.0.0.1/ | grep -q 'Shop OK'; then
  pass site_serves_content "HTTP $code"
else
  fail site_serves_content "HTTP $code"
fi
check nginx_enabled_on_boot systemctl is-enabled --quiet nginx
# removing the shop site is not a fix
grep -rqs 'shop.example.test' /etc/nginx/ || deduct site_removed "no server block for shop.example.test left"
