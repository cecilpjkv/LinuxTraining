sleep 3
check indexer_running systemctl is-active --quiet feed-indexer
[ -f /run/feed-indexer.ok ] && [ $(( $(date +%s) - $(stat -c %Y /run/feed-indexer.ok) )) -lt 6 ] && pass indexer_healthy || fail indexer_healthy "the indexer is not healthy"
pid=$(systemctl show -p MainPID --value feed-indexer)
lim=$(awk '/Max open files/{print $4}' /proc/$pid/limits 2>/dev/null)
[ "${lim:-0}" -ge 4096 ] 2>/dev/null && pass limit_raised "soft limit $lim" || fail limit_raised "soft limit ${lim:-?}"
