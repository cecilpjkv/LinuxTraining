#!/bin/bash
set -e
dnf -y -q install nodejs npm >/dev/null
id nodeapp >/dev/null 2>&1 || useradd -r -s /sbin/nologin -d /opt/shop-api nodeapp
grep -q 'api.shop.example.test' /etc/hosts || echo '127.0.0.1 api.shop.example.test' >> /etc/hosts
mkdir -p /opt/shop-api
cat > /opt/shop-api/server.js <<'JS'
const http = require('http');
// the deploy expects its configuration in the environment
const token = process.env.API_TOKEN;
if (!token) { console.error('FATAL: API_TOKEN not set'); process.exit(1); }
http.createServer((req, res) => {
  console.log(new Date().toISOString(), req.method, req.url);
  if (req.url === '/health') { res.end('ok\n'); return; }
  res.end('SHOP-API-OK\n');
}).listen(3000, '127.0.0.1');
JS
chown -R nodeapp:nodeapp /opt/shop-api
# the environment file the service loads its config from
cat > /etc/shop-api.env <<'ENV'
API_TOKEN=prod-7f3c9a21
ENV
chmod 640 /etc/shop-api.env
cat > /etc/systemd/system/shop-api.service <<'UNIT'
[Unit]
Description=Shop API
After=network.target
[Service]
User=nodeapp
WorkingDirectory=/opt/shop-api
EnvironmentFile=/etc/shop-api.env
ExecStart=/usr/bin/node /opt/shop-api/server.js
Restart=always
RestartSec=2
[Install]
WantedBy=multi-user.target
UNIT
cat > /etc/nginx/conf.d/shop-api.conf <<'CONF'
server {
    listen 80 default_server;
    server_name api.shop.example.test;
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
    }
}
CONF
systemctl daemon-reload
systemctl enable --now nginx shop-api
# --- the break: the deploy removed the env file, so API_TOKEN is gone and the app aborts on start (crash loop)
rm -f /etc/shop-api.env
systemctl restart shop-api 2>/dev/null || true
sleep 2
