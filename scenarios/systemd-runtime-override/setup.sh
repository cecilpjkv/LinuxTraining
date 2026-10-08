#!/bin/bash
set -e
cat > /usr/local/sbin/inventory-api <<'PYX'
#!/usr/bin/python3
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b"inventory ok\n")
    def log_message(self, *a): pass
HTTPServer((os.environ.get("BIND", "127.0.0.1"), int(os.environ.get("PORT", "8081"))), H).serve_forever()
PYX
chmod 755 /usr/local/sbin/inventory-api
printf '[Unit]\nDescription=inventory-api\n\n[Service]\nExecStart=/usr/local/sbin/inventory-api\nRestart=always\nRestartSec=1\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/inventory-api.service
systemctl daemon-reload
systemctl enable --now inventory-api
mkdir -p /etc/systemd/system/inventory-api.service.d /run/systemd/system/inventory-api.service.d
printf '[Service]\nEnvironment=PORT=9081\n' > /etc/systemd/system/inventory-api.service.d/10-test.conf
printf '[Service]\nExecStart=\nExecStart=/usr/local/sbin/inventory-api --debug-port\n' > /run/systemd/system/inventory-api.service.d/50-debug.conf
sed -i 's|^ExecStart=/usr/local/sbin/inventory-api$|ExecStart=/usr/local/sbin/inventory-api|' /etc/systemd/system/inventory-api.service
systemctl daemon-reload
systemctl restart inventory-api || true
