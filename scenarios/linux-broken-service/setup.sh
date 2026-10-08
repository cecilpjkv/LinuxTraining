#!/bin/bash
set -e
useradd -r -s /sbin/nologin inventory 2>/dev/null || true
mkdir -p /opt/inventory/bin
cat > /opt/inventory/bin/inventory-api <<'X'
#!/usr/bin/python3
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers()
        self.wfile.write(b"OK\n" if self.path == "/health" else b"inventory\n")
    def log_message(self, *a): pass
os.makedirs("cache", exist_ok=True)  # relative to the working directory
HTTPServer(("127.0.0.1", int(os.environ.get("PORT", "8081"))), H).serve_forever()
X
chmod 755 /opt/inventory/bin/inventory-api
cat > /etc/systemd/system/inventory-api.service <<'X'
[Unit]
Description=Inventory API
After=network.target

[Service]
User=inventory
WorkingDirectory=/opt/inventory/data
Environment=PORT=8081
ExecStart=/opt/inventory/bin/inventory_api
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
X
systemctl daemon-reload
systemctl start inventory-api || true
