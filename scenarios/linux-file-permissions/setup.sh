#!/bin/bash
set -e
useradd -r -s /sbin/nologin reports 2>/dev/null || true
mkdir -p /opt/reportd /var/lib/reportd
printf '[database]\nhost = 127.0.0.1\nuser = reports\npassword = S3cr3t-Rep0rts!\n' > /opt/reportd/config.ini
cat > /opt/reportd/reportd <<'X'
#!/usr/bin/python3
import configparser, sys, time
c = configparser.ConfigParser()
if not c.read("/opt/reportd/config.ini"):
    sys.exit("reportd: cannot read /opt/reportd/config.ini")
while True:
    with open("/var/lib/reportd/last-run.txt", "w") as f:
        f.write(time.strftime("%F %T") + " report generated\n")
    time.sleep(3)
X
chmod 755 /opt/reportd/reportd
chown -R reports:reports /opt/reportd/config.ini /var/lib/reportd
chmod 600 /opt/reportd/config.ini
cat > /etc/systemd/system/reportd.service <<'X'
[Unit]
Description=Report generator daemon

[Service]
User=reports
ExecStart=/opt/reportd/reportd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
X
systemctl daemon-reload
systemctl enable --now reportd
sleep 2
# the "hardening"
chown root:root /opt/reportd/config.ini /var/lib/reportd
chmod 600 /opt/reportd/config.ini
chmod 700 /var/lib/reportd
systemctl restart reportd || true
rm -f /var/lib/reportd/last-run.txt
