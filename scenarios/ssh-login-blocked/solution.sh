# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/^AllowUsers deploy admin/AllowUsers deploy admin support/' /etc/ssh/sshd_config.d/30-audit.conf
sed -i 's|^from="10.20.0.0/16" ||' /home/support/.ssh/authorized_keys
systemctl restart sshd
