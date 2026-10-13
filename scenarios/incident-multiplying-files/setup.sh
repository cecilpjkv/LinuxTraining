#!/bin/bash
set -e
install -d -m 755 /var/spool/upload
cat > /usr/local/sbin/spoolgen <<'GEN'
#!/bin/bash
while :; do
  head -c 64 /dev/urandom > "/var/spool/upload/.q$RANDOM$RANDOM" 2>/dev/null
  sleep 0.1
done
GEN
chmod 755 /usr/local/sbin/spoolgen
cat > /etc/systemd/system/spooler.service <<'UNIT'
[Unit]
Description=Upload spooler
[Service]
ExecStart=/usr/local/sbin/spoolgen
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now spooler
# also restart on boot via cron
printf '@reboot root /usr/local/sbin/spoolgen &\n' > /etc/cron.d/spooler
sleep 2   # let a backlog of files build up
