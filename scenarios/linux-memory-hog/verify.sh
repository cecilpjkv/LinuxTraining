pid=$(systemctl show -p MainPID --value cache-warmer)
if systemctl is-active --quiet cache-warmer && [ "${pid:-0}" -gt 0 ]; then
  pass cache_running
  rss=$(ps -o rss= -p "$pid" | tr -d ' ')
  [ "${rss:-999999}" -lt 150000 ] && pass cache_small "${rss} kB" || fail cache_small "cache-warmer uses ${rss} kB"
else
  fail cache_running "cache-warmer is not running"; fail cache_small "not running"
fi
mb=$(sed -n 's/^CACHE_MB=\([0-9]*\).*/\1/p' /etc/sysconfig/cache-warmer | tail -1)
[ -n "$mb" ] && [ "$mb" -le 128 ] && pass config_fixed "CACHE_MB=$mb" || fail config_fixed "CACHE_MB=${mb:-unset}"
curl -s -m 5 http://127.0.0.1:8080/ | grep -q 'orders ok' && systemctl is-active --quiet orders-api && pass orders_running || fail orders_running "orders API not answering"
