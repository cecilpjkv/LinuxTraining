# reference fix: stop and disable the service, remove persistence and the generator, clean the directory
systemctl disable --now spooler 2>/dev/null || true
rm -f /etc/systemd/system/spooler.service /usr/local/sbin/spoolgen
systemctl daemon-reload
rm -f /etc/cron.d/spooler
pkill -f spoolgen 2>/dev/null || true
find /var/spool/upload -type f -delete 2>/dev/null || true
