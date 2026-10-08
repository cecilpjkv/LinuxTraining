sleep 3
r=$(getent hosts db.internal | awk '{print $1}')
case "$r" in 127.0.0.1|::1) pass resolves_locally "db.internal = $r";; *) fail resolves_locally "db.internal -> '${r}'";; esac
if [ -f /run/inventory-sync.ok ] && [ $(( $(date +%s) - $(stat -c %Y /run/inventory-sync.ok) )) -lt 10 ]; then pass sync_healthy; else fail sync_healthy "inventory-sync has not connected recently"; fi
