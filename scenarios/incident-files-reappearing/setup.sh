#!/bin/bash
set -e
id deploy >/dev/null 2>&1 || useradd -m -s /bin/bash deploy
install -d -o deploy -g deploy /home/deploy/bin
printf '#!/bin/bash\nfind /home/deploy/tmp -mtime +7 -delete 2>/dev/null\n' > /home/deploy/bin/nightly.sh
chmod 755 /home/deploy/bin/nightly.sh; chown deploy: /home/deploy/bin/nightly.sh
crontab -u deploy - <<'X'
30 1 * * * /home/deploy/bin/nightly.sh
X

# the attacker's seed and payload (payload kept dormant in the lab)
install -d -m 700 /var/lib/.sysseed
printf '#!/bin/sh\n# beacon (dormant in the lab)\nexit 0\n' > /var/lib/.sysseed/.update
chmod 755 /var/lib/.sysseed/.update
cp /var/lib/.sysseed/.update /usr/local/bin/.update

# persistence 1: a systemd watcher that recreates the file whenever it is missing
cat > /usr/local/sbin/fsupdate-loop <<'LOOP'
#!/bin/bash
while :; do
  [ -e /usr/local/bin/.update ] || cp /var/lib/.sysseed/.update /usr/local/bin/.update
  chmod 755 /usr/local/bin/.update 2>/dev/null
  sleep 2
done
LOOP
chmod 755 /usr/local/sbin/fsupdate-loop
cat > /etc/systemd/system/fsupdate.service <<'UNIT'
[Unit]
Description=Filesystem update helper
[Service]
ExecStart=/usr/local/sbin/fsupdate-loop
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now fsupdate

# persistence 2: a root cron that also restores it every minute
printf '* * * * * root cp -f /var/lib/.sysseed/.update /usr/local/bin/.update 2>/dev/null\n' > /etc/cron.d/system-update
