#!/bin/bash
set -e
printf '#!/bin/bash\nmkdir -p /var/backups/db && date > /var/backups/db/backup-$(date +%%F).txt\n' > /usr/local/sbin/db-backup
chmod 755 /usr/local/sbin/db-backup
printf '[Unit]\nDescription=Database backup\n\n[Service]\nType=oneshot\nExecStart=/usr/local/sbin/db-backup\n' > /etc/systemd/system/db-backup.service
printf '[Unit]\nDescription=Daily database backup\n\n[Timer]\nOnCalendar=dialy\nPersistent=true\n\n[Install]\nWantedBy=timers.target\n' > /etc/systemd/system/db-backup.timer
systemctl daemon-reload
