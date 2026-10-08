# reference fix (not imported; used by scripts/check_scenarios.py)
chmod 644 /etc/passwd /etc/group
chmod 000 /etc/shadow /etc/gshadow
systemctl restart status-api
