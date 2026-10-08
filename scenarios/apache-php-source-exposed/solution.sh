# reference fix (not imported; used by scripts/check_scenarios.py)
mv /etc/httpd/conf.d/php.conf.unused /etc/httpd/conf.d/php.conf
systemctl enable --now php-fpm
systemctl restart httpd
