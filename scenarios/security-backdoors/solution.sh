# reference fix (not imported; used by scripts/check_scenarios.py)
rm -f /usr/local/bin/.update-helper
sed -i '/^sysbackup:/d' /etc/passwd /etc/shadow
sed -i '/203.0.113.66/d' /root/.ssh/authorized_keys
