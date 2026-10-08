# reference fix (not imported; used by scripts/check_scenarios.py)
chown -R archive:archive /srv/archive
systemctl unmask archive
systemctl enable --now archive
sed -i 's|^0 \* \* \* \* /usr/local/sbin/archive-export|0 * * * * archive /usr/local/sbin/archive-export|' /etc/cron.d/archive-export
