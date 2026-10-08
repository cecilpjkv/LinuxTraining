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
# run the scheduler the way this server is set up to: the system cron entry if any, else the built-in one
line=$(grep -rhE '^[^#].*(wp-cron|wp cron|cron event run)' /etc/cron.d /var/spool/cron 2>/dev/null | head -1)
if [ -n "$line" ]; then u=root; cmd=$(echo "$line" | awk '{for(i=6;i<=NF;i++) printf "%s ", $i}')
  if id -u "$(echo "$line" | awk '{print $6}')" >/dev/null 2>&1; then u=$(echo "$line" | awk '{print $6}'); cmd=$(echo "$line" | awk '{for(i=7;i<=NF;i++) printf "%s ", $i}'); fi
  runuser -u "$u" -- sh -c "cd /tmp; $cmd" >/dev/null 2>&1 </dev/null; how="system cron"
elif grep -Eq "^\s*define\(\s*'DISABLE_WP_CRON',\s*true" /srv/www/wp/wp-config.php; then how="none (WP-Cron off, no system cron)"
else curl -s -o /dev/null -H 'Host: wp.example.test' http://127.0.0.1/; how="built-in"; fi
sleep 2
st=$(mysql -N -B wordpress </dev/null -e "SELECT post_status FROM wp_posts WHERE post_name='scheduled-post'" 2>/dev/null)
[ "$st" = publish ] && pass scheduled_published "via $how" || fail scheduled_published "status: ${st:-?} (scheduler: $how)"
if grep -Eq "^\s*define\(\s*'DISABLE_WP_CRON',\s*true" /srv/www/wp/wp-config.php; then [ -n "$line" ] && pass scheduler_exists "system cron" || fail scheduler_exists "WP-Cron is off and no system cron job replaces it"; else pass scheduler_exists "built-in WP-Cron"; fi
