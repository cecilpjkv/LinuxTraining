pgrep -f spoolgen >/dev/null 2>&1 && fail gen_stopped "the generator is still running" || pass gen_stopped
if systemctl is-active --quiet spooler 2>/dev/null || systemctl is-enabled --quiet spooler 2>/dev/null; then
  fail service_gone "the spooler service is still active or enabled"
else pass service_gone; fi
if grep -rqs 'spoolgen\|spooler' /etc/cron.d /etc/crontab /var/spool/cron 2>/dev/null; then
  fail persist_gone "a cron job still starts it on boot"
else pass persist_gone; fi
# the directory must not be growing and must not hold a backlog
n1=$(find /var/spool/upload -type f 2>/dev/null | wc -l); sleep 2
n2=$(find /var/spool/upload -type f 2>/dev/null | wc -l)
if [ "$n1" = "$n2" ] && [ "$n2" -lt 5 ]; then pass dir_clean "$n2 files, stable"; else fail dir_clean "$n1 -> $n2 files"; fi
