# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/^LISTEN=.*/LISTEN=0.0.0.0/' /etc/metrics-api.conf
systemctl restart metrics-api
