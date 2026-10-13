line=$(grep -v '^\s*#' /etc/cron.d/order-export | grep export-orders | head -1)
if [ -n "$line" ] && ! printf '%s' "$line" | grep -qP '(?<!\\)%'; then pass percent_escaped; else fail percent_escaped "the cron line still has an unescaped %"; fi
check script_executable test -x /usr/local/bin/export-orders
f=/var/backups/orders/orders-$(date +%F).csv
if [ -s "$f" ] && head -1 "$f" | grep -q '^order_id,' && grep -q "CMD (/usr/local/bin/export-orders" /var/log/cron 2>/dev/null; then
  pass export_written
else
  fail export_written "$f was not written (by cron)"
fi
