#!/bin/bash
set -e
mkdir -p /opt/cache /opt/orders
cat > /etc/sysconfig/cache-warmer <<'X'
# cache-warmer settings
# CACHE_MB: size of the in-memory product cache in MB.
#   Production servers (8 GB RAM): 380. Small servers (under 1 GB RAM): 64 or less.
CACHE_MB=380
X
cat > /opt/cache/cache-warmer <<'X'
#!/usr/bin/python3
import os, time
mb = int(os.environ.get("CACHE_MB", "64"))
cache = bytearray(mb * 1024 * 1024)
for i in range(0, len(cache), 4096):
    cache[i] = 1  # touch every page
print(f"cache-warmer: {mb} MB product cache loaded", flush=True)
while True:
    time.sleep(60)
X
cat > /opt/orders/orders-api <<'X'
#!/usr/bin/python3
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b"orders ok\n")
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", 8080), H).serve_forever()
X
chmod 755 /opt/cache/cache-warmer /opt/orders/orders-api
cat > /etc/systemd/system/cache-warmer.service <<'X'
[Unit]
Description=Product cache warmer

[Service]
EnvironmentFile=/etc/sysconfig/cache-warmer
ExecStart=/opt/cache/cache-warmer
Restart=always

[Install]
WantedBy=multi-user.target
X
cat > /etc/systemd/system/orders-api.service <<'X'
[Unit]
Description=Orders API (port 8080)

[Service]
ExecStart=/opt/orders/orders-api
Restart=always

[Install]
WantedBy=multi-user.target
X
systemctl daemon-reload
systemctl enable --now orders-api cache-warmer
sleep 4
logger -t kernel "Out of memory: Killed process 4121 (orders-api) total-vm:412532kB, anon-rss:61220kB"
