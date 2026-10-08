# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's|^ip addr add 10.5.0.1/24 dev ln-backend|ip addr add 10.50.0.1/24 dev ln-backend|; s|^# ip link set ln-backend up  (disabled for maintenance)|ip link set ln-backend up|' /usr/local/sbin/backend-net
systemctl restart backend-net
