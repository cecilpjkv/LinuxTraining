# reference fix (not imported; used by scripts/check_scenarios.py)
rm -rf /run/systemd/system/inventory-api.service.d
rm -f /etc/systemd/system/inventory-api.service.d/10-test.conf
systemctl daemon-reload
systemctl restart inventory-api
