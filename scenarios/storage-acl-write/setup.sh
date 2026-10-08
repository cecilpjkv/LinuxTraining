#!/bin/bash
set -e
groupadd -f media
id mediaapp >/dev/null 2>&1 || useradd -r -g media -s /sbin/nologin mediaapp
mkdir -p /srv/media/uploads
chown root:media /srv/media/uploads
chmod 2775 /srv/media/uploads
cat > /usr/local/sbin/media-api <<'X'
#!/usr/bin/python3
import sys, time
while True:
    try:
        with open("/srv/media/uploads/.write-probe", "w") as f:
            f.write(time.strftime("%F %T\n"))
        open("/run/media-api/ok", "w").write(time.strftime("%F %T\n"))
    except OSError as e:
        print(f"media-api: cannot store upload: {e}", file=sys.stderr, flush=True)
    time.sleep(2)
X
chmod 755 /usr/local/sbin/media-api
printf '[Unit]\nDescription=Media API\n\n[Service]\nUser=mediaapp\nRuntimeDirectory=media-api\nExecStart=/usr/local/sbin/media-api\nRestart=always\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/media-api.service
systemctl daemon-reload
# a read-only rule left over from an old backup job
setfacl -m u:mediaapp:r-x /srv/media/uploads
rm -f /srv/media/uploads/.write-probe
systemctl enable --now media-api
