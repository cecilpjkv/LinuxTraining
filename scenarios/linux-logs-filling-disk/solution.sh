# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/^LOG_LEVEL=.*/LOG_LEVEL=INFO/' /etc/ledger-sync.conf
sed -i 's|^/var/log/ledger-sync.log|/var/log/app/ledger-sync.log|' /etc/logrotate.d/ledger-sync
truncate -s 0 /var/log/app/ledger-sync.log
systemctl restart ledger-sync
sleep 2
