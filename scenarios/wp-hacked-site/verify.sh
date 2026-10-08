sleep 3  # graceful reloads answer with the old config for a moment; opcache re-reads files every 2 s
site_ok() {  # site_ok CHECK HOST PATH TEXT [scheme]
  local code
  code=$(curl -sk -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "${5:-http}://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for ${5:-http}://$2$3"; fi
}
WP="wp --allow-root --path=/srv/www/wp"
wp_ok() { site_ok "$1" wp.example.test "$2" "$3"; }
# fast CHECK MAXSECONDS HOST PATH: the page answers 200 within MAXSECONDS
fast() { local t c; t=$(curl -s -o /dev/null -m 30 -w '%{http_code} %{time_total}' -H "Host: $3" "http://127.0.0.1$4"); c=${t%% *}; t=${t#* }
  if [ "$c" = 200 ] && python3 -c "import sys; sys.exit(0 if $t < $2 else 1)"; then pass "$1" "${t}s"; else fail "$1" "HTTP $c in ${t}s (limit ${2}s)"; fi; }
curl -s -m 15 -H 'Host: wp.example.test' http://127.0.0.1/ | grep -q 'cheap pills' && fail no_spam "the spam link is still injected" || pass no_spam
grep -q 'base64_decode' "$(cat /root/.lt-theme)/functions.php" && fail theme_clean "the theme still contains the injected code" || pass theme_clean
[ ! -e /srv/www/wp/wp-content/uploads/2024/10/cache.php ] && pass backdoor_removed || fail backdoor_removed "the uploads backdoor is still there"
admins=$(mysql -N -B wordpress </dev/null -e "SELECT u.user_login FROM wp_users u JOIN wp_usermeta m ON m.user_id=u.ID WHERE m.meta_key='wp_capabilities' AND m.meta_value LIKE '%administrator%' ORDER BY 1" 2>/dev/null | tr '\n' ' ')
[ "$admins" = "wpadmin " ] && pass only_real_admin || fail only_real_admin "administrators: $admins"
mkdir -p /srv/www/wp/wp-content/uploads/lt && echo '<?php echo "EXEC-" . (1+1);' > /srv/www/wp/wp-content/uploads/lt/t.php && chown -R apache: /srv/www/wp/wp-content/uploads/lt
curl -s -m 10 -H 'Host: wp.example.test' http://127.0.0.1/wp-content/uploads/lt/t.php | grep -q 'EXEC-2' && fail uploads_no_php "PHP in uploads still executes" || pass uploads_no_php
rm -rf /srv/www/wp/wp-content/uploads/lt
wp_ok site_works /hello-training/ 'WP-POST-OK'
