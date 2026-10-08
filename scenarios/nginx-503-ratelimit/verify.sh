sleep 1  # a graceful reload lets old workers answer for a moment
ok=0
for i in $(seq 1 20); do [ "$(curl -s -o /dev/null -m 5 -w '%{http_code}' -H 'Host: shop.example.test' http://127.0.0.1/)" = 200 ] && ok=$((ok+1)); done
[ "$ok" -eq 20 ] && pass browsing_works "20/20" || fail browsing_works "$ok of 20 quick requests succeeded"
nginx -T 2>/dev/null | grep -Eq '^\s*limit_req\s+zone=' && pass protection_kept || fail protection_kept "rate limiting was removed"
check config_valid nginx -t
