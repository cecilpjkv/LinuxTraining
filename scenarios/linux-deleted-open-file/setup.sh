#!/bin/bash
set -e
mkdir -p /opt/report-worker
cat > /opt/report-worker/worker <<'PY'
#!/usr/bin/python3
# processes report batches; healthy while its log volume has room
import os, time
LOG = "/var/log/app/worker.log"
log = open(LOG, "a")
while True:
    try:
        log.write(time.strftime("%Y-%m-%d %H:%M:%S") + " INFO processed report batch\n")
        log.flush()
        st = os.statvfs("/var/log/app")
        if st.f_bavail * st.f_frsize > 8 * 1024 * 1024:
            with open("/run/report-worker.ok", "w") as f:
                f.write(str(int(time.time())))
    except OSError:
        pass  # disk full: the batch is retried
    time.sleep(1)
PY
chmod 755 /opt/report-worker/worker
cat > /etc/systemd/system/report-worker.service <<'UNIT'
[Unit]
Description=Report worker

[Service]
ExecStart=/opt/report-worker/worker
Restart=always

[Install]
WantedBy=multi-user.target
UNIT
chmod 755 /var/log/app
systemctl daemon-reload
systemctl enable --now report-worker
for i in $(seq 1 20); do [ -s /var/log/app/worker.log ] && break; sleep 0.5; done
# a debug flood went into the open log (same file), then someone deleted the file while the worker still writes it
yes '2026-10-12 23:59:59 DEBUG payload dump: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' | head -c 30M >> /var/log/app/worker.log || true
rm -f /var/log/app/worker.log /run/report-worker.ok
