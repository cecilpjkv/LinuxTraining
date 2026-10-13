sleep 3
avail=$(df -Pk /var/log/app | awk 'NR==2{print $4}')
[ "$avail" -ge 16384 ] && pass space_freed "$((avail/1024)) MB free" || fail space_freed "only $((avail/1024)) MB free on /var/log/app"
if systemctl is-active --quiet report-worker && [ -f /run/report-worker.ok ] && [ $(( $(date +%s) - $(cat /run/report-worker.ok) )) -lt 10 ]; then
  pass worker_healthy
else
  fail worker_healthy "the health file /run/report-worker.ok is not being updated"
fi
pid=$(systemctl show -p MainPID --value report-worker)
if [ -f /var/log/app/worker.log ] && [ $(( $(date +%s) - $(stat -c %Y /var/log/app/worker.log) )) -lt 10 ] && \
   [ "${pid:-0}" -gt 0 ] && ! ls -l /proc/$pid/fd 2>/dev/null | grep -q '(deleted)'; then
  pass log_visible
else
  fail log_visible "the worker does not write /var/log/app/worker.log (or still holds a deleted file)"
fi
