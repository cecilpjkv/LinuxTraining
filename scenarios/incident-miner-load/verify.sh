pgrep -u svc >/dev/null 2>&1 && fail miner_stopped "svc still has a running process" || pass miner_stopped
if systemctl is-active --quiet kdevsync 2>/dev/null || systemctl is-enabled --quiet kdevsync 2>/dev/null; then
  fail service_gone "the kdevsync service is still active or enabled"
else pass service_gone; fi
if grep -rqs 'kdevd\|kdevsync\|kworker' /etc/cron.d /etc/crontab /var/spool/cron 2>/dev/null; then
  fail persist_gone "a cron job still respawns the miner"
else pass persist_gone; fi
code=$(curl -s -o /tmp/.lt-m -m 5 -w '%{http_code}' http://127.0.0.1:9100/ 2>/dev/null)
[ "$code" = 200 ] && grep -q 'metrics ok' /tmp/.lt-m && pass metrics_kept "HTTP $code" || fail metrics_kept "HTTP ${code:-none}"
