# reference fix (not imported; used by scripts/check_scenarios.py)
mkdir -p /etc/systemd/system/feed-indexer.service.d
printf '[Service]\nLimitNOFILE=8192\n' > /etc/systemd/system/feed-indexer.service.d/limits.conf
systemctl daemon-reload
systemctl restart feed-indexer
