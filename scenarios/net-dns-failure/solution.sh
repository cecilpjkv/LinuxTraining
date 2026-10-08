# reference fix (not imported; used by scripts/check_scenarios.py)
printf 'nameserver 127.0.0.1\n' > /etc/resolv.conf
systemctl enable --now dnsmasq
