#!/bin/bash
set -e
mkdir -p /srv/app /var/backups/app
echo "settings" > /srv/app/settings.json
cat > /usr/local/bin/app-backup.sh <<'X'
#!/bin/bash
# application backup (cron, every 5 minutes)
tar -czf /var/backups/app/app-$(date +%F-%H%M%S).tar.gz -C /srv app
X
chmod 644 /usr/local/bin/app-backup.sh
for d in 3 2 1; do f=/var/backups/app/app-$(date -d "$d days ago" +%F-0200)00.tar.gz; tar -czf "$f" -C /srv app; touch -d "$d days ago" "$f"; done
cat > /etc/cron.d/app-backup <<'X'
# application backup
*/5 * * * * /usr/local/bin/app-backup.sh
X
