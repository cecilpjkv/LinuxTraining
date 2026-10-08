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
c=$(curl -sk -o /tmp/.lt-b -w '%{http_code}' -H 'Host: wp.example.test' https://127.0.0.1/hello-training/)
[ "$c" = 200 ] && grep -q 'WP-POST-OK' /tmp/.lt-b && pass https_post || fail https_post "https post answered $c"
c=$(curl -sk -o /tmp/.lt-b -w '%{http_code}' -H 'Host: wp.example.test' https://127.0.0.1/)
[ "$c" = 200 ] && grep -q 'Training Blog' /tmp/.lt-b && pass https_home || fail https_home "https home answered $c"
grep -q 'http://wp.example.test' /tmp/.lt-b && fail secure_links "the page links to http:// (mixed content)" || pass secure_links
