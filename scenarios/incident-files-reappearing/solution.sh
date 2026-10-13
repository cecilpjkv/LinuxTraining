# reference fix: stop the persistence, then remove the file and the seed
systemctl disable --now fsupdate 2>/dev/null || true
rm -f /etc/systemd/system/fsupdate.service /usr/local/sbin/fsupdate-loop
systemctl daemon-reload
rm -f /etc/cron.d/system-update
rm -rf /var/lib/.sysseed
rm -f /usr/local/bin/.update
