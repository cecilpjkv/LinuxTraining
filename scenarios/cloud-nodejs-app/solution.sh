# reference fix (not imported; used by scripts/check_scenarios.py)
dnf -y -q install nodejs npm
useradd -r -s /sbin/nologin -d /opt/hello-node nodeapp
mkdir -p /opt/hello-node
cat > /opt/hello-node/server.js <<'JS'
const http = require('http');
http.createServer((req, res) => {
  console.log(new Date().toISOString(), req.method, req.url);
  if (req.url === '/health') { res.end('ok\n'); return; }
  res.end('Hello from Node\n');
}).listen(3000);
JS
chown -R nodeapp:nodeapp /opt/hello-node
cat > /etc/systemd/system/hello-node.service <<'UNIT'
[Unit]
Description=Hello Node application
After=network.target
[Service]
User=nodeapp
WorkingDirectory=/opt/hello-node
ExecStart=/usr/bin/node /opt/hello-node/server.js
Restart=always
RestartSec=2
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now hello-node
sleep 2
