#!/bin/bash
set -e
grep -q 'shop.example.test' /etc/hosts || echo '127.0.0.1 shop.example.test blog.example.test api.example.test portal.example.test' >> /etc/hosts
echo 'PRICES-V1' > /srv/catalog-version 2>/dev/null || { mkdir -p /srv; echo 'PRICES-V1' > /srv/catalog-version; }
cat > /usr/local/sbin/catalog <<'X'
#!/usr/bin/python3
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(open("/srv/catalog-version", "rb").read())
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", 8120), H).serve_forever()
X
chmod 755 /usr/local/sbin/catalog
printf '[Unit]\nDescription=Catalogue service\n\n[Service]\nExecStart=/usr/local/sbin/catalog\nRestart=always\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/catalog.service
mkdir -p /var/cache/nginx/shop && chown nginx /var/cache/nginx/shop
sed -i 's|^http {|http {\n    proxy_cache_path /var/cache/nginx/shop keys_zone=shop:10m inactive=2d;|' /etc/nginx/nginx.conf
printf 'server {\n    listen 80;\n    server_name shop.example.test;\n    location / {\n        proxy_pass http://127.0.0.1:8120;\n        proxy_cache shop;\n        proxy_cache_valid 200 1d;\n        proxy_ignore_headers Cache-Control Expires;\n    }\n}\n' > /etc/nginx/conf.d/shop.conf
systemctl daemon-reload
systemctl enable --now catalog nginx
for i in $(seq 1 30); do curl -s -H 'Host: shop.example.test' http://127.0.0.1/prices | grep -q PRICES-V1 && break; sleep 0.5; done
echo 'PRICES-V2' > /srv/catalog-version
curl -s -H 'Host: shop.example.test' http://127.0.0.1/prices | grep -q PRICES-V1   # the stale copy is served
