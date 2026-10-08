#!/bin/bash
set -e
mkdir -p /var/lib/feeds
for i in $(seq 1 2000); do : > /var/lib/feeds/feed-$i; done
cat > /usr/local/sbin/feed-indexer <<'X'
#!/usr/bin/python3
import glob, sys, time
handles = []
for f in sorted(glob.glob("/var/lib/feeds/feed-*")):
    try:
        handles.append(open(f))
    except OSError as e:
        sys.exit(f"feed-indexer: {e}")
print(f"feed-indexer: {len(handles)} feeds open", flush=True)
while True:
    open("/run/feed-indexer.ok", "w").write(time.strftime("%T\n")); time.sleep(2)
X
chmod 755 /usr/local/sbin/feed-indexer
printf '[Unit]\nDescription=Feed indexer\n\n[Service]\nExecStart=/usr/local/sbin/feed-indexer\nLimitNOFILE=1024\nRestart=on-failure\nRestartSec=5\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/feed-indexer.service
systemctl daemon-reload
systemctl enable feed-indexer
systemctl start feed-indexer || true
