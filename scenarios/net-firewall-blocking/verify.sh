cat > /tmp/.lt-nettest <<'X'
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
sleep 1
bash /tmp/.lt-nettest 8080 >/dev/null 2>&1 && pass app_reachable || fail app_reachable "port 8080 is not reachable from the network"
if nft list chain inet filter input 2>/dev/null | grep -q 'policy drop'; then pass firewall_kept; else fail firewall_kept "the default-deny firewall is gone"; fi
nft list chain inet filter input 2>/dev/null | grep -Eq 'tcp dport 22 accept' && pass ssh_rule_kept || fail ssh_rule_kept "the SSH rule is gone"
if systemctl is-enabled --quiet nftables && systemctl restart nftables && bash /tmp/.lt-nettest 8080 >/dev/null 2>&1 && nft list chain inet filter input | grep -q 'policy drop'; then
  pass persistent
else
  fail persistent "after reloading the saved firewall configuration port 8080 is blocked (or the firewall is off)"
fi
rm -f /tmp/.lt-nettest
