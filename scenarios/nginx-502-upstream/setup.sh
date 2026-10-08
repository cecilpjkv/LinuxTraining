#!/bin/bash
set -e
mkdir -p /srv/www/shop
cat > /srv/www/shop/index.html <<'HTML'
<!doctype html><title>Example Shop</title><h1>Example Shop</h1><p>Shop OK</p>
HTML
grep -q 'shop.example.test' /etc/hosts || echo '127.0.0.1 shop.example.test blog.example.test api.example.test portal.example.test' >> /etc/hosts
mkdir -p /opt/shop-api
cat > /opt/shop-api/server <<'X'
#!/usr/bin/python3
import json, os
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.send_header("Content-Type", "application/json"); self.end_headers()
        self.wfile.write(json.dumps({"status": "ok", "service": "shop-api"}).encode())
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", int(os.environ["PORT"])), H).serve_forever()
X
chmod 755 /opt/shop-api/server
printf '# shop-api settings\nPORT=8001\n' > /etc/shop-api.env
cat > /etc/systemd/system/shop-api.service <<'X'
[Unit]
Description=Shop API

[Service]
EnvironmentFile=/etc/shop-api.env
ExecStart=/opt/shop-api/server
Restart=always

[Install]
WantedBy=multi-user.target
X
cat > /etc/nginx/conf.d/api.conf <<'CONF'
server {
    listen 80;
    server_name api.example.test;
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
    }
}
CONF
systemctl daemon-reload
systemctl enable --now shop-api nginx
curl -s -o /dev/null -H 'Host: api.example.test' http://127.0.0.1/health
