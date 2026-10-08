sleep 1  # a graceful reload lets old workers answer for a moment
site_ok() {  # site_ok CHECK HOST PATH TEXT [scheme]
  local code
  code=$(curl -sk -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "${5:-http}://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for ${5:-http}://$2$3"; fi
}
site_ok current_prices shop.example.test /prices 'PRICES-V2'
v=$(nginx -T 2>/dev/null | sed -n 's/.*proxy_cache_valid[^0-9]*200 \([0-9]*[smhd]\);.*/\1/p' | head -1)
secs() { case "$1" in *s) echo ${1%s};; *m) echo $(( ${1%m}*60 ));; *h) echo $(( ${1%h}*3600 ));; *d) echo $(( ${1%d}*86400 ));; *) echo 999999;; esac; }
[ -n "$v" ] && [ "$(secs $v)" -le 600 ] && [ "$(secs $v)" -gt 0 ] && pass short_validity "200 cached $v" || fail short_validity "cache validity: ${v:-none}"
nginx -T 2>/dev/null | grep -Eq '^\s*proxy_cache\s+shop;' && pass cache_kept || fail cache_kept "caching was switched off"
