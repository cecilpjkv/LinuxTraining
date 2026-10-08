# reference fix (not imported; used by scripts/check_scenarios.py)
chown reports:reports /opt/reportd/config.ini /var/lib/reportd
systemctl restart reportd
