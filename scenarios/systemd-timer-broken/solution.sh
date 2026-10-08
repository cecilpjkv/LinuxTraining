# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/^OnCalendar=dialy/OnCalendar=daily/' /etc/systemd/system/db-backup.timer
systemctl daemon-reload
systemctl enable --now db-backup.timer
