# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's|        tcp dport 22 accept comment "ssh"|        tcp dport 22 accept comment "ssh"\n        tcp dport 8080 accept comment "orders web"|' /etc/sysconfig/nftables.conf
systemctl restart nftables
