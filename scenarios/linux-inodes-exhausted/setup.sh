#!/bin/bash
set -e
mkdir -p /srv/spool/sessions
cd /srv/spool/sessions
# old sessions a cleanup job should have removed: as many as the filesystem takes (tmpfs inode accounting varies)
i=0; while : > "sess_old_$i" 2>/dev/null; do i=$((i+1)); done
find . -name 'sess_old_*' -exec touch -d '3 days ago' {} +
for j in $(seq 0 19); do rm -f "sess_old_$j"; done
for j in $(seq 1 20); do echo "user=$j" > "sess_active_$j"; done
cat > /etc/cron.d/session-cleanup <<'X'
# remove sessions older than a day
*/30 * * * * root find /srv/spool/session -type f -mtime +1 -delete
X
mkdir -p /var/log/shop
echo "$(date '+%F %T') ERROR Could not create session file: No space left on device" >> /var/log/shop/app.log
