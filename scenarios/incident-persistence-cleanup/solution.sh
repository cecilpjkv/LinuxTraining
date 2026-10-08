# reference fix (not imported; used by scripts/check_scenarios.py)
rm -f /var/tmp/.font-cache /etc/cron.d/0anacron-update /etc/sudoers.d/90-cloud-init-users /etc/ssh/sshd_config.d/00-cloud.conf
systemctl disable --now sysmetrics; rm -f /etc/systemd/system/sysmetrics.service; systemctl daemon-reload
sed -i '/203.0.113.66/d' /home/deploy/.ssh/authorized_keys
systemctl restart sshd
