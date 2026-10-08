#!/bin/bash
set -e
cat > /usr/local/sbin/backend-api <<'X'
#!/usr/bin/python3
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b"backend ok\n")
    def log_message(self, *a): pass
HTTPServer(("0.0.0.0", 8443), H).serve_forever()
X
cat > /usr/local/sbin/backend-net <<'X'
#!/bin/bash
# backend network (10.50.0.0/24) through ln-backend; the backend host is 10.50.0.10
ip netns list | grep -qw backend || ip netns add backend
if ! ip link show ln-backend >/dev/null 2>&1; then
  ip link add ln-backend type veth peer name eth-backend
  ip link set eth-backend netns backend
fi
n="nsenter --net=/run/netns/backend"   # not "ip -n": it remounts /sys, which this server may not do
$n ip addr replace 10.50.0.10/24 dev eth-backend
$n ip link set eth-backend up
$n ip link set lo up
# this server's side
ip addr flush dev ln-backend
ip addr add 10.50.0.1/24 dev ln-backend
ip link set ln-backend up
X
chmod 755 /usr/local/sbin/backend-api /usr/local/sbin/backend-net
cat > /etc/systemd/system/backend-net.service <<'X'
[Unit]
Description=Backend network (ln-backend)
Before=backend-api.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/backend-net

[Install]
WantedBy=multi-user.target
X
cat > /etc/systemd/system/backend-api.service <<'X'
[Unit]
Description=Backend API (simulated backend host, network namespace "backend")
After=backend-net.service
Requires=backend-net.service

[Service]
ExecStart=/usr/bin/nsenter --net=/run/netns/backend /usr/local/sbin/backend-api
Restart=always

[Install]
WantedBy=multi-user.target
X
systemctl daemon-reload
systemctl enable --now backend-net backend-api
sleep 1
curl -s -m 3 http://10.50.0.10:8443/ >/dev/null
# yesterday's change
sed -i 's|^ip addr add 10.50.0.1/24 dev ln-backend|ip addr add 10.5.0.1/24 dev ln-backend|; s|^ip link set ln-backend up|# ip link set ln-backend up  (disabled for maintenance)|' /usr/local/sbin/backend-net
systemctl restart backend-net
ip link set ln-backend down
