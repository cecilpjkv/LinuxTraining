#!/bin/bash
set -e
cat > /etc/metrics-api.conf <<'X'
# metrics API
LISTEN=127.0.0.1
PORT=9100
X
cat > /usr/local/sbin/metrics-api <<'X'
#!/usr/bin/python3
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
cfg = dict(l.strip().split("=", 1) for l in open("/etc/metrics-api.conf") if "=" in l and not l.startswith("#"))
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b"node_up 1\n")
    def log_message(self, *a): pass
HTTPServer((cfg.get("LISTEN", "127.0.0.1"), int(cfg.get("PORT", "9100"))), H).serve_forever()
X
chmod 755 /usr/local/sbin/metrics-api
printf '[Unit]\nDescription=Metrics API\n\n[Service]\nExecStart=/usr/local/sbin/metrics-api\nRestart=always\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/metrics-api.service
systemctl daemon-reload
systemctl enable --now metrics-api
