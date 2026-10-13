sleep 1
if ! id shopdev >/dev/null 2>&1; then
  for c in user_ok key_login shop_owned blog_protected; do fail $c "no user shopdev"; done
else
  uid=$(id -u shopdev); sh=$(getent passwd shopdev | cut -d: -f7)
  [ "$uid" -ge 1000 ] && [ "$uid" != 65534 ] && pass user_ok "uid $uid, $sh" || { [ "$uid" -gt 0 ] && pass user_ok "system user uid $uid" || fail user_ok "uid $uid"; }
  out=$(ssh -n -i /var/lib/lt-keys/shopdev -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 shopdev@127.0.0.1 'id -un' 2>&1)
  [ "$(echo "$out" | tail -1)" = shopdev ] && pass key_login || fail key_login "$(echo "$out" | tail -1)"
  bad=$(find /srv/www/shop ! -user shopdev ! -path '/srv/www/shop/uploads/*' 2>/dev/null | head -3)
  if [ -n "$bad" ]; then fail shop_owned "not shopdev's: $(echo $bad)"
  elif runuser -u shopdev -- sh -c 'echo "<?php function catalog_status() { return \"Shop OK\"; }" > /srv/www/shop/lib/catalog.php && touch /srv/www/shop/.lt-edit && rm /srv/www/shop/.lt-edit' 2>/dev/null; then pass shop_owned
  else fail shop_owned "shopdev cannot change the files"; fi
  if runuser -u shopdev -- cat /srv/www/blog/config.php >/dev/null 2>&1; then fail blog_protected "shopdev can read it"; else pass blog_protected; fi
  { id -nG shopdev | grep -Eqw 'wheel|root|sudo|adm'; } || [ "$uid" = 0 ] || sudo -l -U shopdev 2>/dev/null | grep -q '(ALL' && deduct too_much_power "$(id shopdev)"
fi
tag=$RANDOM
r=$(curl -s -m 5 -H 'Host: shop.example.test' "http://127.0.0.1/upload.php?n=$tag")
echo "$r" | grep -q "stored upload-$tag" && [ -f /srv/www/shop/uploads/upload-$tag.txt ] && pass uploads_work || fail uploads_work "${r:-no answer}"
rm -f /srv/www/shop/uploads/upload-$tag.txt
n=0; d=""
curl -s -m 5 -H 'Host: shop.example.test' http://127.0.0.1/ | grep -q 'Shop OK' && n=$((n+1)) || d="$d shop: HTTP $(http_code -H 'Host: shop.example.test' http://127.0.0.1/);"
curl -s -m 5 -H 'Host: blog.example.test' http://127.0.0.1/ | grep -q 'Blog OK</p>' && n=$((n+1)) || d="$d blog: HTTP $(http_code -H 'Host: blog.example.test' http://127.0.0.1/);"
[ $n = 2 ] && pass sites_work || partial sites_work "$(echo "scale=2; $n/2" | bc)" "$d"
ww=$(find /srv/www -perm -o+w ! -type l 2>/dev/null | head -3)
[ -n "$ww" ] && deduct world_writable "$(echo $ww)"
