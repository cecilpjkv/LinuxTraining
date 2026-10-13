sleep 3  # opcache re-reads changed files every 2 s
# as the site user: a debug.log created by root would be unwritable for PHP-FPM
WP="runuser -u apache -- /usr/bin/php /usr/local/bin/wp --path=/srv/www/wp"
cfg=/srv/www/wp/wp-config.php
const() { $WP eval "echo defined('$1') ? var_export(constant('$1'), true) : 'undefined';" 2>/dev/null </dev/null; }
dbg=$(const WP_DEBUG); dlog=$(const WP_DEBUG_LOG); ddisp=$(const WP_DEBUG_DISPLAY)
if [ "$dbg" = true ] && [ -n "$dlog" ] && [ "$dlog" != false ] && [ "$dlog" != undefined ]; then pass debug_enabled "WP_DEBUG_LOG=$dlog"; else fail debug_enabled "WP_DEBUG=$dbg WP_DEBUG_LOG=$dlog"; fi
case "$dlog" in "'"*) logf=$(echo "$dlog" | tr -d "'"); case "$logf" in /*) ;; *) logf=/srv/www/wp/$logf;; esac;; *) logf=/srv/www/wp/wp-content/debug.log;; esac
tag=lt$RANDOM$RANDOM
code=$(curl -s -o /tmp/.lt-body -m 15 -w '%{http_code}' -H 'Host: wp.example.test' "http://127.0.0.1/?shop_debug_test=$tag")
sleep 1
grep -q "Shop debug test $tag" "$logf" 2>/dev/null && pass debug_logged "$logf" || fail debug_logged "message not found in $logf"
if grep -q "Shop debug test $tag" /tmp/.lt-body; then fail display_off "the notice is shown on the page"
elif [ "$ddisp" = true ] || { [ "$dbg" = true ] && [ "$ddisp" = undefined ] && ! $WP eval 'exit(ini_get("display_errors") ? 1 : 0);' >/dev/null 2>&1 </dev/null; }; then fail display_off "WP_DEBUG_DISPLAY is on"
else pass display_off; fi
grep -q 'Hello Training' /tmp/.lt-body && [ "$code" = 200 ] || { curl -s -m 15 -H 'Host: wp.example.test' http://127.0.0.1/hello-training/ | grep -q 'WP-POST-OK' || deduct site_broken "home page HTTP $code"; }
ev=$($WP cron event list --fields=hook,recurrence --format=csv 2>/dev/null </dev/null | grep '^shop_cleanup_carts,')
case "$ev" in *"1 hour"*) pass event_scheduled "$ev";; "") fail event_scheduled "not scheduled";; *) fail event_scheduled "$ev (not hourly)";; esac
grep -Eq "^\s*define\(\s*'DISABLE_WP_CRON',\s*true" $cfg || deduct wp_cron_reenabled
# run the system cron job the way cron would, with a probe event that is due now
$WP cron event schedule shop_cron_probe now --0=$tag --quiet </dev/null 2>/dev/null
pat='^[^#].*(wp-cron|wp cron|cron event run)'
src=$(grep -rlE "$pat" /etc/cron.d /etc/crontab /var/spool/cron 2>/dev/null | head -1)
line=$([ -n "$src" ] && grep -hE "$pat" "$src" | head -1)
if [ -n "$line" ]; then
  case "$src" in  # a user's crontab has no user field
    /var/spool/cron/*) u=$(basename "$src"); cmd=$(echo "$line" | awk '{for(i=6;i<=NF;i++) printf "%s ", $i}');;
    *) u=$(echo "$line" | awk '{print $6}'); cmd=$(echo "$line" | awk '{for(i=7;i<=NF;i++) printf "%s ", $i}');;
  esac
  every=$(echo "$line" | awk '{print $1}')
  runuser -u "$u" -- sh -c "cd /tmp; $cmd" >/dev/null 2>&1 </dev/null
  sleep 1
  if [ -n "$($WP option get shop_cron_probe_$tag 2>/dev/null </dev/null)" ]; then
    case "$every" in '*/5'|'*/1'|'*/2'|'*/3'|'*/4'|'*'|'0-59/5'|'*/5,'*) pass system_cron "$u: $cmd";; *) fail system_cron "runs at minute '$every', not every 5 minutes";; esac
  else fail system_cron "the cron job ($u: $cmd) did not run the due events"; fi
else fail system_cron "no cron job runs WordPress's events"; fi
[ -n "$($WP option get shop_cleanup_last_run 2>/dev/null </dev/null)" ] && pass event_ran || fail event_ran "shop_cleanup_carts has never run"
