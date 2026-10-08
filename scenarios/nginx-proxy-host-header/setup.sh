#!/bin/bash
set -e
grep -q 'shop.example.test' /etc/hosts || echo '127.0.0.1 shop.example.test blog.example.test api.example.test portal.example.test' >> /etc/hosts
cat > /usr/local/sbin/orders-api <<'X'
#!/usr/bin/python3
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        host = (self.headers.get("Host") or "").split(":")[0]
        if host != "api.example.test":
            self.send_response(421); self.end_headers(); self.wfile.write(b"unknown host\n"); return
        self.send_response(200); self.end_headers(); self.wfile.write(b"orders api ok\n")
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", 8100), H).serve_forever()
X
chmod 755 /usr/local/sbin/orders-api
printf '[Unit]\nDescription=Orders API\n\n[Service]\nExecStart=/usr/local/sbin/orders-api\nRestart=always\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/orders-api.service
printf 'upstream orders { server 127.0.0.1:8100; }\nserver {\n    listen 80;\n    server_name api.example.test;\n    location / {\n        proxy_pass http://orders;\n    }\n}\n' > /etc/nginx/conf.d/api.conf
systemctl daemon-reload
systemctl enable --now orders-api nginx
