# reference fix (not imported; used by scripts/check_scenarios.py)
chgrp ssh_keys /etc/ssh/ssh_host_*_key 2>/dev/null || true
chmod 640 /etc/ssh/ssh_host_*_key
rm -f /etc/ssh/sshd_config.d/20-listen.conf
systemctl restart sshd
