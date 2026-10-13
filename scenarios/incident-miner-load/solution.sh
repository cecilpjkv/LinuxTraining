# reference fix: stop and disable the miner, remove its persistence; leave metrics running
systemctl disable --now kdevsync 2>/dev/null || true
rm -f /etc/systemd/system/kdevsync.service /usr/local/sbin/.kdevd
systemctl daemon-reload
rm -f /etc/cron.d/kdevsync
pkill -u svc 2>/dev/null || true
