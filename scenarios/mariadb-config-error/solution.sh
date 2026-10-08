# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/^max_conections/max_connections/' /etc/my.cnf.d/zz-tuning.cnf
systemctl restart mariadb
