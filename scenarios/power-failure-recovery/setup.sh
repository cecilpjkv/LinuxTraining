#!/bin/bash
set -e
chmod 755 /var/log/app
mkdir -p /var/lib/paygw
cat > /usr/local/sbin/paygw <<'X'
#!/bin/bash
lock=/var/lib/paygw/paygw.lock
if [ -e $lock ]; then echo "paygw: lock file $lock exists (pid $(cat $lock)): another instance is running" >&2; exit 1; fi
echo $$ > $lock; trap 'rm -f $lock' EXIT
while :; do date +%s > /run/paygw.ok; sleep 2; done
X
cat > /usr/local/sbin/event-logger <<'X'
#!/bin/bash
while :; do
  if echo "$(date) event" >> /var/log/app/events.log 2>/dev/null; then date +%s > /run/event-logger.ok; else echo "event-logger: No space left on device" >&2; exit 1; fi
  sleep 2
done
X
cat > /usr/local/sbin/reconcile <<'X'
#!/bin/bash
echo "reconciled $(date)" > /var/lib/paygw/reconcile.last
X
chmod 755 /usr/local/sbin/paygw /usr/local/sbin/event-logger /usr/local/sbin/reconcile
printf '[Unit]\nDescription=Payment gateway\n\n[Service]\nExecStart=/usr/local/sbin/paygw\nRestart=on-failure\nRestartSec=2\nStartLimitBurst=3\nStartLimitIntervalSec=600\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/paygw.service
printf '[Unit]\nDescription=Event logger\n\n[Service]\nExecStart=/usr/local/sbin/event-logger\nRestart=on-failure\nRestartSec=2\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/event-logger.service
printf '[Unit]\nDescription=Reconciliation\n\n[Service]\nType=oneshot\nExecStart=/usr/local/sbin/reconcile\n' > /etc/systemd/system/reconcile.service
printf '[Unit]\nDescription=Reconciliation every 10 minutes\n\n[Timer]\nOnCalendar=*:0/10\n\n[Install]\nWantedBy=timers.target\n' > /etc/systemd/system/reconcile.timer
systemctl daemon-reload
systemctl enable paygw event-logger reconcile.timer
# the crash: a stale lock, a full log volume (core dump of the crash), the timer lost
echo 48213 > /var/lib/paygw/paygw.lock
head -c 15M /dev/zero > /var/log/app/core.event-logger.48190 2>/dev/null || true
cat /dev/zero >> /var/log/app/events.log 2>/dev/null || true
systemctl start paygw event-logger 2>/dev/null || true
sleep 8
systemctl disable reconcile.timer
