# reference fix (not imported; used by scripts/check_scenarios.py)
chmod 755 /usr/local/bin/app-backup.sh
sed -i 's|^\*/5 \* \* \* \* /usr/local/bin/app-backup.sh|*/5 * * * * root /usr/local/bin/app-backup.sh|' /etc/cron.d/app-backup
