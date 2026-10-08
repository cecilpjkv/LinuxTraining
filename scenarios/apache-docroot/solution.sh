# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's|    DocumentRoot /var/www/portal|    DocumentRoot /srv/www/portal|' /etc/httpd/conf.d/portal.conf
systemctl reload httpd
