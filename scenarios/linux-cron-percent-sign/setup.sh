#!/bin/bash
set -e
mkdir -p /var/backups/orders
cat > /usr/local/bin/export-orders <<'SH'
#!/bin/bash
# prints today's orders as CSV
echo "order_id,customer,total"
for i in 1 2 3; do echo "$(date +%Y%m%d)$i,customer$i,$((i * 17)).00"; done
SH
chmod 644 /usr/local/bin/export-orders
cat > /etc/cron.d/order-export <<'CRON'
# order export (every minute while testing; nightly later)
SHELL=/bin/bash
* * * * * root /usr/local/bin/export-orders > /var/backups/orders/orders-$(date +%F).csv 2>> /var/log/order-export.log
CRON
systemctl is-active --quiet crond || systemctl start crond
