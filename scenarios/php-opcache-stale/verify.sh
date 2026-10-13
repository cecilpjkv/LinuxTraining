sleep 1
H='Host: shop2.example.test'
# the deployed change (RELEASE-2 on disk) must now be served
body=$(curl -s -m 10 -H "$H" http://127.0.0.1/)
echo "$body" | grep -q 'RELEASE-2' && pass code_live "served: $(echo $body|tr -d '\n')" || fail code_live "still serving: $(echo $body|tr -d '\n')"
echo "$body" | grep -q 'RELEASE-' && pass site_works || fail site_works "no RELEASE marker"
# future deploys must appear without a manual restart: cache a file, change it, and see the
# change. This is self-contained (its own file) so it does not disturb index.php above. Each
# write ages past opcache.file_update_protection (2s) before the request.
f=/srv/www/shop2/ver.php
printf '<?php echo "VER-A";' > "$f"; chown apache:apache "$f"; sleep 3
curl -s -o /dev/null -m 10 -H "$H" http://127.0.0.1/ver.php   # caches VER-A
printf '<?php echo "VER-B";' > "$f"; chown apache:apache "$f"; sleep 3
got=$(curl -s -m 10 -H "$H" http://127.0.0.1/ver.php)
echo "$got" | grep -q 'VER-B' && pass future_deploys "picked up the change" || fail future_deploys "served '$got' after the file changed; opcache is not revalidating"
rm -f "$f"
