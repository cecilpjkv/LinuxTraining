#!/bin/bash
set -e
grep -q 'shop.example.test' /etc/hosts || echo '127.0.0.1 shop.example.test blog.example.test api.example.test portal.example.test' >> /etc/hosts
cat > /usr/local/sbin/account-svc <<'X'
#!/usr/bin/python3
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        if self.path.startswith("/account"):
            self.send_header("X-Permissions", "p" * 12000)
        self.end_headers(); self.wfile.write(b"ACCOUNT-OK\n")
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", 8110), H).serve_forever()
X
chmod 755 /usr/local/sbin/account-svc
printf '[Unit]\nDescription=Account service\n\n[Service]\nExecStart=/usr/local/sbin/account-svc\nRestart=always\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/account-svc.service
printf 'server {\n    listen 80;\n    server_name api.example.test;\n    location / {\n        proxy_pass http://127.0.0.1:8110;\n        proxy_set_header Host $host;\n    }\n}\n' > /etc/nginx/conf.d/api.conf
systemctl daemon-reload
systemctl enable --now account-svc nginx
