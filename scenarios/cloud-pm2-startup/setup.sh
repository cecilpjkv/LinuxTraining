#!/bin/bash
set -e
dnf -y -q install nodejs npm >/dev/null
id appops >/dev/null 2>&1 || useradd -m -s /bin/bash appops
grep -q 'pm2.example.test' /etc/hosts || echo '127.0.0.1 pm2.example.test' >> /etc/hosts
mkdir -p /opt/pm2app
cat > /opt/pm2app/server.js <<'JS'
const http = require('http');
http.createServer((req, res) => {
  console.log(new Date().toISOString(), req.method, req.url);
  if (req.url === '/health') { res.end('ok\n'); return; }
  res.end('PM2APP-OK\n');
}).listen(3000, '127.0.0.1');
JS
chown -R appops:appops /opt/pm2app
cat > /etc/nginx/conf.d/pm2app.conf <<'CONF'
server {
    listen 80 default_server;
    server_name pm2.example.test;
    location / { proxy_pass http://127.0.0.1:3000; proxy_set_header Host $host; }
}
CONF
systemctl enable --now nginx
# start the app under pm2 as appops; it is running now...
runuser -u appops -- bash -lc 'cd /opt/pm2app && pm2 start server.js --name pm2app' </dev/null
sleep 2
# ...but nothing brings it back on boot: no pm2 boot service and no saved process list
rm -f /etc/systemd/system/pm2-appops.service /etc/systemd/system/multi-user.target.wants/pm2-appops.service
systemctl daemon-reload
rm -f /home/appops/.pm2/dump.pm2
