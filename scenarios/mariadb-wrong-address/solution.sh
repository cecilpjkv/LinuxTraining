# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/^bind-address = .*/bind-address = 127.0.0.1/; s/^port = 3307/port = 3306/' /etc/my.cnf.d/zz-network.cnf
systemctl restart mariadb
