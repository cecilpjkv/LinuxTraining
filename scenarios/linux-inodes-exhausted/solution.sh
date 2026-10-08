# reference fix (not imported; used by scripts/check_scenarios.py)
find /srv/spool/sessions -type f -mtime +1 -delete
sed -i 's|find /srv/spool/session |find /srv/spool/sessions |' /etc/cron.d/session-cleanup
