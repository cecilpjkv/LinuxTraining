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
c=$(curl -s -o /tmp/.lt-b -w '%{http_code} %{redirect_url}' -H 'Host: wp.example.test' http://127.0.0.1/)
case "$c" in "200 "*) grep -q 'Training Blog' /tmp/.lt-b && pass no_redirect || fail no_redirect "no blog content";; *) fail no_redirect "answered $c";; esac
grep -q 'wp-old.example.test' /tmp/.lt-b && fail links_new_domain "the page still links to the old domain" || pass links_new_domain
wp_ok post_page /hello-training/ 'WP-POST-OK'
