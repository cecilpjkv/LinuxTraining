sleep 3
avail=$(df -Pk /var/log/app | awk 'NR==2{print $4}')
[ "$avail" -ge 16384 ] && pass space_ok "$((avail/1024)) MB free" || fail space_ok "only $((avail/1024)) MB free"
if systemctl is-active --quiet ledger-sync && [ -f /run/ledger-sync.ok ] && [ $(( $(date +%s) - $(stat -c %Y /run/ledger-sync.ok) )) -lt 10 ]; then
  pass service_healthy
else
  fail service_healthy "the health file is not being updated"
fi
grep -Eiq '^LOG_LEVEL=("|)(INFO|WARNING|WARN|ERROR)("|)$' /etc/ledger-sync.conf && pass log_level_fixed || fail log_level_fixed "LOG_LEVEL is still DEBUG"
if grep -q '^/var/log/app/ledger-sync.log' /etc/logrotate.d/ledger-sync && logrotate -d -s /tmp/.lt-logrotate.status /etc/logrotate.d/ledger-sync >/dev/null 2>&1; then
  pass rotation_fixed
else
  fail rotation_fixed "logrotate does not rotate /var/log/app/ledger-sync.log"
fi
