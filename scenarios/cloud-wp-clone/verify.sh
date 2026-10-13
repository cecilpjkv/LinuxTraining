sleep 3
S=/srv/www/staging
WPS="runuser -u apache -- /usr/bin/php /usr/local/bin/wp --path=$S"
[ -f $S/wp-settings.php ] && grep -q BAKERY-MENU-OK $S/wp-content/uploads/2026/09/menu.txt 2>/dev/null && pass files_copied || fail files_copied "WordPress or its uploads missing in $S"
cget() { php -r 'error_reporting(0); $c = file_get_contents($argv[1]); if (preg_match("/define\(\s*[\x27\"]" . $argv[2] . "[\x27\"]\s*,\s*[\x27\"]([^\x27\"]*)/", $c, $m)) echo $m[1];' $S/wp-config.php "$1" 2>/dev/null; }
db=$(cget DB_NAME); u=$(cget DB_USER); p=$(cget DB_PASSWORD); h=$(cget DB_HOST); h=${h:-localhost}
if [ "$db" = wp_staging ] && [ -n "$u" ] && [ "$u" != wpuser ] && [ "$u" != root ] && mysql -h "$h" -u "$u" -p"$p" wp_staging </dev/null -e 'SELECT 1' >/dev/null 2>&1; then pass staging_db "$u@$db"
else fail staging_db "DB_NAME=${db:-?} DB_USER=${u:-?}"; fi
if [ -z "$u" ] || [ "$u" = wpuser ] || [ "$u" = root ]; then fail db_user_isolated "staging uses ${u:-no} user"
elif mysql -h "$h" -u "$u" -p"$p" wordpress </dev/null -e 'SELECT COUNT(*) FROM wp_posts' >/dev/null 2>&1; then fail db_user_isolated "$u can read the production database"
else pass db_user_isolated; fi
c=$(mysql -N -B wp_staging </dev/null -e "SELECT COUNT(*) FROM wp_posts WHERE post_name='fresh-bread' AND post_status='publish'" 2>/dev/null)
[ "$c" = 1 ] && pass data_imported || fail data_imported "the post is not in wp_staging"
code=$(curl -s -o /tmp/.lt-body -m 15 -w '%{http_code}' -H 'Host: staging.example.test' http://127.0.0.1/)
code2=$(curl -s -o /tmp/.lt-body2 -m 15 -w '%{http_code}' -H 'Host: staging.example.test' http://127.0.0.1/fresh-bread/)
if [ "$code" = 200 ] && grep -q 'Fresh bread every morning' /tmp/.lt-body && grep -q WP-POST-OK /tmp/.lt-body2 && ! grep -q 'wp\.example\.test' /tmp/.lt-body && [ "$code2" = 200 ]; then pass staging_works
elif grep -q 'wp\.example\.test' /tmp/.lt-body; then fail staging_works "the page links to wp.example.test"
else fail staging_works "home HTTP $code, post HTTP $code2"; fi
# a change on staging must not show up in production
tag=lt$RANDOM
if [ "$db" = wp_staging ] && $WPS post create --post_title="Staging $tag" --post_status=publish --quiet </dev/null >/dev/null 2>&1; then
  n=$(mysql -N -B wordpress </dev/null -e "SELECT COUNT(*) FROM wp_posts WHERE post_title='Staging $tag'")
  [ "$n" = 0 ] && pass changes_isolated || fail changes_isolated "a staging post appeared in production"
  mysql wp_staging </dev/null -e "DELETE FROM wp_posts WHERE post_title='Staging $tag'" 2>/dev/null
else fail changes_isolated "staging is not on its own database"; fi
pu=$(mysql -N -B wordpress </dev/null -e "SELECT option_value FROM wp_options WHERE option_name IN ('siteurl','home')" | sort -u)
pc=$(mysql -N -B wordpress </dev/null -e "SELECT COUNT(*) FROM wp_posts")
grep -q "'wordpress'" /srv/www/wp/wp-config.php && [ "$pu" = http://wp.example.test ] && [ "$pc" = "$(cat /var/lib/.lt-prod-posts)" ] \
  && curl -s -m 15 -H 'Host: wp.example.test' http://127.0.0.1/fresh-bread/ | grep -q WP-POST-OK || deduct production_changed "siteurl/home: $(echo $pu), posts: $pc"
