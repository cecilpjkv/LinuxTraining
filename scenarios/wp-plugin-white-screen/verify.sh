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
wp_ok site_works / 'Training Blog'
curl -s -m 15 -H 'Host: wp.example.test' http://127.0.0.1/ | grep -q 'name="seo-helper"' && pass seo_active || fail seo_active "SEO Helper is not active"
c=$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: wp.example.test' http://127.0.0.1/wp-login.php); [ "$c" = 200 ] && pass admin_reachable || fail admin_reachable "wp-login.php answers $c"
