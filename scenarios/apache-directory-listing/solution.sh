# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's|    Options Indexes FollowSymLinks|    Options -Indexes +FollowSymLinks|' /etc/httpd/conf.d/portal.conf
mv /srv/www/portal/files/portal-backup-2024.sql /root/
systemctl reload httpd
