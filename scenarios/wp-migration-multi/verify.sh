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
c=$(curl -s -o /tmp/.lt-b -w '%{http_code}' -H 'Host: wp.example.test' http://127.0.0.1/)
[ "$c" = 200 ] && grep -q 'Training Blog' /tmp/.lt-b && pass home_page || fail home_page "home answered $c"
wp_ok post_page /hello-training/ 'WP-POST-OK'
grep -q 'wp-old.example.test' /tmp/.lt-b && fail new_address "the page still uses the old address" || pass new_address
if runuser -u apache -- php -r 'exit(@mkdir("/srv/www/wp/wp-content/uploads/lt/x", 0755, true) ? 0 : 1);'; then pass uploads_work; rm -rf /srv/www/wp/wp-content/uploads/lt; else fail uploads_work "the web server cannot write uploads"; fi
[ -z "$(find /srv/www/wp -perm -o+w | head -1)" ] && pass not_world_writable || fail not_world_writable "files writable by everybody"
