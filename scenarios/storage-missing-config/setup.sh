#!/bin/bash
set -e
groupadd -f acme
id acme >/dev/null 2>&1 || useradd -r -g acme -s /sbin/nologin acme
mkdir -p /etc/acme
cat > /etc/acme/agent.conf <<'X'
# ACME monitoring agent
endpoint = https://monitor.acme.example/api/v2
api_token = 7f3a9c2e-51b4-4d8e-b0a6-2c9f1e7d4b83
interval = 30
X
chown root:acme /etc/acme/agent.conf
chmod 640 /etc/acme/agent.conf
sha256sum /etc/acme/agent.conf > /root/.lt-acme.sha256
mkdir -p /var/backups
tar -czpf /var/backups/etc-backup-$(date -d yesterday +%F).tar.gz -C / etc/acme etc/hostname etc/crontab 2>/dev/null
cat > /usr/local/sbin/acme-agent <<'X'
#!/usr/bin/python3
import sys, time
try:
    conf = open("/etc/acme/agent.conf").read()
except OSError as e:
    sys.exit(f"acme-agent: cannot read configuration /etc/acme/agent.conf: {e}")
if "api_token" not in conf:
    sys.exit("acme-agent: api_token missing in /etc/acme/agent.conf")
while True:
    time.sleep(30)
X
chmod 755 /usr/local/sbin/acme-agent
printf '[Unit]\nDescription=ACME monitoring agent\n\n[Service]\nUser=acme\nExecStart=/usr/local/sbin/acme-agent\nRestart=on-failure\nRestartSec=5\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/acme-agent.service
systemctl daemon-reload
systemctl enable --now acme-agent
rm -f /etc/acme/agent.conf
systemctl restart acme-agent || true
