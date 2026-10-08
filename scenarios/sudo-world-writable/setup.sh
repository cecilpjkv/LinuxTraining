#!/bin/bash
set -e
cat > /usr/local/sbin/shop-api <<'PYX'
#!/usr/bin/python3
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b"shop api\n")
    def log_message(self, *a): pass
HTTPServer((os.environ.get("BIND", "127.0.0.1"), int(os.environ.get("PORT", "8091"))), H).serve_forever()
PYX
chmod 755 /usr/local/sbin/shop-api
printf '[Unit]\nDescription=shop-api\n\n[Service]\nExecStart=/usr/local/sbin/shop-api\nRestart=always\nRestartSec=1\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/shop-api.service
systemctl daemon-reload
systemctl enable --now shop-api
id deploy >/dev/null 2>&1 || useradd -m -s /bin/bash deploy
echo 'deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart shop-api' > /etc/sudoers.d/deploy
chmod 666 /etc/sudoers.d/deploy
