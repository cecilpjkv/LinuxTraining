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
if runuser -u apache -- php -r 'exit(@mkdir("/srv/www/wp/wp-content/uploads/lt-test/x", 0755, true) && file_put_contents("/srv/www/wp/wp-content/uploads/lt-test/x/a.jpg", "img") ? 0 : 1);'; then pass uploads_writable; rm -rf /srv/www/wp/wp-content/uploads/lt-test; else fail uploads_writable "the web server user cannot write uploads"; fi
ww=$(find /srv/www/wp -perm -o+w | head -3 | tr '\n' ' ')
[ -z "$ww" ] && pass not_world_writable || fail not_world_writable "writable by everybody: $ww"
wp_ok site_works / 'Training Blog'
