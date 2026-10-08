#!/bin/bash
set -e
useradd -u 1500 -M -s /sbin/nologin archive
mkdir -p /srv/archive/data /srv/archive/exports
for i in 1 2 3; do echo "doc $i" > /srv/archive/data/doc-$i.txt; done
chown -R 1205:1205 /srv/archive
chmod 750 /srv/archive /srv/archive/data /srv/archive/exports
cat > /usr/local/sbin/archive <<'X'
#!/bin/bash
while :; do
  if ls /srv/archive/data >/dev/null 2>&1 && date > /srv/archive/data/.alive; then date +%s > /run/archive/ok; else echo "archive: permission denied on /srv/archive" >&2; fi
  sleep 2
done
X
printf '#!/bin/bash\ntar -czf /srv/archive/exports/export-$(date +%%H).tar.gz -C /srv/archive data\n' > /usr/local/sbin/archive-export
chmod 755 /usr/local/sbin/archive /usr/local/sbin/archive-export
printf '[Unit]\nDescription=Archive service\n\n[Service]\nUser=archive\nRuntimeDirectory=archive\nExecStart=/usr/local/sbin/archive\nRestart=always\n\n[Install]\nWantedBy=multi-user.target\n' > /usr/lib/systemd/system/archive.service
printf '0 * * * * /usr/local/sbin/archive-export\n' > /etc/cron.d/archive-export
systemctl daemon-reload
systemctl enable archive
systemctl mask archive
