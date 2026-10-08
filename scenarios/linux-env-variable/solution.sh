# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/^APP_MODE=.*/APP_MODE=production/; s|^QUEUE_DIR=.*|QUEUE_DIR=/var/spool/billing/incoming|' /etc/billing/billing.env
systemctl restart billing-worker
