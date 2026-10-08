# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's|/opt/inventory/bin/inventory_api|/opt/inventory/bin/inventory-api|' /etc/systemd/system/inventory-api.service
mkdir -p /opt/inventory/data && chown inventory: /opt/inventory/data
systemctl daemon-reload
systemctl enable inventory-api
systemctl restart inventory-api
sleep 2
