#!/bin/bash
set -e
cat > /usr/local/sbin/lt-nettest <<'X'
#!/bin/bash
# lt-nettest PORT: connect to this server's port from a client on the 192.168.77.0/30 network
port=${1:-8080}
ip netns del lt-client 2>/dev/null; ip link del lt-h 2>/dev/null
ip netns add lt-client
ip link add lt-h type veth peer name lt-c
ip link set lt-c netns lt-client
ip addr add 192.168.77.1/30 dev lt-h; ip link set lt-h up
# nsenter, not "ip netns exec"/"ip -n": those remount /sys, which a user-namespaced lab may not do
n="nsenter --net=/run/netns/lt-client"
$n ip addr add 192.168.77.2/30 dev lt-c; $n ip link set lt-c up; $n ip link set lo up
code=$($n curl -s -m 5 -o /dev/null -w '%{http_code}' "http://192.168.77.1:$port/")
ip netns del lt-client 2>/dev/null; ip link del lt-h 2>/dev/null
if [ "${code:-000}" != 000 ]; then echo "port $port: reachable from the network (HTTP $code)"; else echo "port $port: NOT reachable from the network"; exit 1; fi
X
chmod 755 /usr/local/sbin/lt-nettest
cat > /etc/systemd/system/lt-nettest@.service <<'X'
[Unit]
Description=Network reachability test for port %i

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/lt-nettest %i
X
cat > /usr/local/bin/test-from-network <<'X'
#!/bin/bash
# test-from-network PORT: is this server's PORT reachable for clients on the network? (provided by the network team)
p=${1:?usage: test-from-network PORT}
systemctl start "lt-nettest@$p.service" >/dev/null 2>&1
journalctl -u "lt-nettest@$p.service" -n 1 -o cat --no-pager
X
chmod 755 /usr/local/bin/test-from-network
systemctl daemon-reload
cat > /usr/local/sbin/orders-web <<'X'
#!/usr/bin/python3
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b"orders ok\n")
    def log_message(self, *a): pass
HTTPServer(("0.0.0.0", 8080), H).serve_forever()
X
chmod 755 /usr/local/sbin/orders-web
printf '[Unit]\nDescription=Orders web application\n\n[Service]\nExecStart=/usr/local/sbin/orders-web\nRestart=always\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/orders-web.service
cat > /etc/sysconfig/nftables.conf <<'X'
#!/usr/sbin/nft -f
# host firewall (security policy SP-3): default deny inbound
flush ruleset
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        iifname "lo" accept
        ct state established,related accept
        ip protocol icmp accept
        tcp dport 22 accept comment "ssh"
    }
}
X
systemctl daemon-reload
systemctl enable --now orders-web nftables
