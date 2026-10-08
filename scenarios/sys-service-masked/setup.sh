#!/bin/bash
set -e
cat > /usr/local/sbin/notify-api <<'PYX'
#!/usr/bin/python3
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b"notify ok\n")
    def log_message(self, *a): pass
HTTPServer((os.environ.get("BIND", "127.0.0.1"), int(os.environ.get("PORT", "8090"))), H).serve_forever()
PYX
chmod 755 /usr/local/sbin/notify-api
printf '[Unit]\nDescription=notify-api\n\n[Service]\nExecStart=/usr/local/sbin/notify-api\nRestart=always\nRestartSec=1\n\n[Install]\nWantedBy=multi-user.target\n' > /usr/lib/systemd/system/notify-api.service
systemctl daemon-reload
systemctl enable --now notify-api
systemctl disable --now notify-api
systemctl mask notify-api
