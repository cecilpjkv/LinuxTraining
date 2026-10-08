# reference fix (not imported; used by scripts/check_scenarios.py)
rm -f /var/lib/paygw/paygw.lock /var/log/app/core.*
: > /var/log/app/events.log
systemctl reset-failed paygw event-logger
systemctl restart paygw event-logger
systemctl enable --now reconcile.timer
