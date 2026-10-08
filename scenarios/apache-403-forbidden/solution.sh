# reference fix (not imported; used by scripts/check_scenarios.py)
printf '<Directory /srv/www/portal>\n    Require all granted\n</Directory>\n' >> /etc/httpd/conf.d/portal.conf
systemctl reload httpd
