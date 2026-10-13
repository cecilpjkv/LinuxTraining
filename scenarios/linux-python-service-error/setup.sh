#!/bin/bash
set -e
id pyapp >/dev/null 2>&1 || useradd -r -s /sbin/nologin -d /opt/pyapp pyapp
mkdir -p /opt/pyapp
# the app reads its greeting from a file next to it (so the working directory matters)
echo 'PYAPP-OK' > /opt/pyapp/message.txt
cat > /opt/pyapp/app.py <<'PY'
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

# the greeting lives in a file in the current working directory
with open('message.txt') as f:
    GREETING = f.read().strip().encode()

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        sys.stderr.write("%s %s\n" % (self.command, self.path)); sys.stderr.flush()
        self.send_response(200); self.end_headers()
        self.wfile.write(b"ok\n" if self.path == "/health" else GREETING + b"\n")
    def log_message(self, *a):
        pass

HTTPServer(("127.0.0.1", 8080), H).serve_forever()
PY
chown -R pyapp:pyapp /opt/pyapp
# the service: a bad deploy left it with a missing interpreter and no working directory
cat > /etc/systemd/system/pyapp.service <<'UNIT'
[Unit]
Description=Internal Python tool
After=network.target
[Service]
User=pyapp
ExecStart=/usr/bin/python /opt/pyapp/app.py
Restart=always
RestartSec=2
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable pyapp 2>/dev/null || true
systemctl start pyapp 2>/dev/null || true
sleep 1
