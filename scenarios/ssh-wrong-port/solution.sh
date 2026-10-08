# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/^Port 2222/Port 22/' /etc/ssh/sshd_config
systemctl restart sshd
