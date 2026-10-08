sleep 3
[ -f /run/paygw.ok ] && [ $(( $(date +%s) - $(stat -c %Y /run/paygw.ok) )) -lt 6 ] && systemctl is-active --quiet paygw && pass paygw_running || fail paygw_running "the payment gateway is not running"
[ -f /run/event-logger.ok ] && [ $(( $(date +%s) - $(stat -c %Y /run/event-logger.ok) )) -lt 6 ] && pass logger_running || fail logger_running "the event logger is not writing"
avail=$(df -Pk /var/log/app | awk 'NR==2{print $4}'); [ "$avail" -ge 4096 ] && pass log_space || fail log_space "$((avail/1024)) MB free"
if systemctl is-enabled --quiet reconcile.timer && systemctl is-active --quiet reconcile.timer && systemctl start reconcile.service && [ -f /var/lib/paygw/reconcile.last ]; then pass reconcile_scheduled; else fail reconcile_scheduled "the reconciliation is not scheduled or fails"; fi
grep -qs 'rm -f $lock' /usr/local/sbin/paygw && systemctl is-enabled --quiet paygw && pass recovers_alone || fail recovers_alone "paygw is not enabled (or its lock handling was removed)"
