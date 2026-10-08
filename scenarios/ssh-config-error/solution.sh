# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/^PubkeyAuthentication yse/PubkeyAuthentication yes/' /etc/ssh/sshd_config.d/40-company.conf
systemctl restart sshd
