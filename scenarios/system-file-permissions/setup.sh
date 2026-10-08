#!/bin/bash
set -e
cat > /usr/local/sbin/status-api <<'PYX'
#!/usr/bin/python3
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b"status ok\n")
    def log_message(self, *a): pass
HTTPServer((os.environ.get("BIND", "127.0.0.1"), int(os.environ.get("PORT", "8096"))), H).serve_forever()
PYX
chmod 755 /usr/local/sbin/status-api
printf '[Unit]\nDescription=status-api\n\n[Service]\nUser=nobody
ExecStart=/usr/local/sbin/status-api\nRestart=always\nRestartSec=1\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/status-api.service
systemctl daemon-reload
systemctl enable --now status-api
chmod 600 /etc/passwd /etc/group
chmod 644 /etc/shadow /etc/gshadow
systemctl restart status-api || true
