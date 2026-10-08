#!/bin/bash
set -e
useradd -r -s /sbin/nologin billing 2>/dev/null || true
mkdir -p /etc/billing /opt/billing /var/spool/billing/incoming /var/spool/billing/done
for i in 1001 1002 1003; do echo "{\"invoice\": $i}" > /var/spool/billing/incoming/job-$i.json; done
chown -R billing: /var/spool/billing
cat > /opt/billing/worker <<'X'
#!/usr/bin/python3
import os, shutil, sys, time
mode = os.environ.get("APP_MODE", "")
if mode not in ("production", "staging"):
    sys.exit(f"billing-worker: invalid APP_MODE {mode!r} (expected production or staging)")
queue = os.environ.get("QUEUE_DIR", "")
if not os.path.isdir(queue):
    sys.exit(f"billing-worker: queue directory {queue!r} does not exist")
done = os.path.join(os.path.dirname(queue.rstrip("/")), "done")
print(f"billing-worker: {mode}, processing {queue}", flush=True)
while True:
    for f in sorted(os.listdir(queue)):
        shutil.move(os.path.join(queue, f), os.path.join(done, f))
        print(f"processed {f}", flush=True)
    time.sleep(2)
X
chmod 755 /opt/billing/worker
cat > /etc/billing/billing.env <<'X'
# billing worker settings (moved from the unit file during maintenance)
APP_MODE=prodution
QUEUE_DIR=/var/spool/billing/queue
LOG_LEVEL=info
X
cat > /etc/systemd/system/billing-worker.service <<'X'
[Unit]
Description=Billing worker

[Service]
User=billing
EnvironmentFile=/etc/billing/billing.env
ExecStart=/opt/billing/worker
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
X
systemctl daemon-reload
systemctl enable --now billing-worker
