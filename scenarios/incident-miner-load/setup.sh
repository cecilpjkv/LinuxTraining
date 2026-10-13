#!/bin/bash
set -e
id svc >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin svc

# legitimate monitoring agent on 127.0.0.1:9100 (must keep running)
cat > /usr/local/sbin/metrics-agent <<'PY'
#!/usr/bin/python3
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b"metrics ok\n")
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", 9100), H).serve_forever()
PY
chmod 755 /usr/local/sbin/metrics-agent
cat > /etc/systemd/system/metrics.service <<'UNIT'
[Unit]
Description=Monitoring agent
[Service]
ExecStart=/usr/local/sbin/metrics-agent
Restart=always
[Install]
WantedBy=multi-user.target
UNIT

# the miner: a CPU burner disguised with a kernel-thread name, run as svc
cat > /usr/local/sbin/.kdevd <<'MINE'
#!/bin/bash
exec -a '[kworker/0:2]' bash -c 'while :; do :; done'
MINE
chmod 755 /usr/local/sbin/.kdevd
cat > /etc/systemd/system/kdevsync.service <<'UNIT'
[Unit]
Description=Kernel device sync
[Service]
User=svc
ExecStart=/usr/local/sbin/.kdevd
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now metrics kdevsync
# persistence: respawn the miner from cron if it is not running
printf '*/5 * * * * svc pgrep -u svc -f kworker >/dev/null || /usr/local/sbin/.kdevd &\n' > /etc/cron.d/kdevsync
sleep 1
