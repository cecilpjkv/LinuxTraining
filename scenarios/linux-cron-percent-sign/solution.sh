# reference fix (not imported; used by scripts/check_scenarios.py)
chmod 755 /usr/local/bin/export-orders
sed -i 's/date +%F/date +\\%F/' /etc/cron.d/order-export
for i in $(seq 1 75); do [ -s /var/backups/orders/orders-$(date +%F).csv ] && break; sleep 1; done
sleep 1
