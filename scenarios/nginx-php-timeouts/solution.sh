# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/fastcgi_read_timeout 5s;/fastcgi_read_timeout 60s;/' /etc/nginx/conf.d/shop.conf
sed -i 's/^max_execution_time = 6/max_execution_time = 60/' /etc/php.d/90-limits.ini
sed -i 's/^php_admin_value\[max_execution_time\] = 6/php_admin_value[max_execution_time] = 60/' /etc/php-fpm.d/www.conf
systemctl restart php-fpm
systemctl reload nginx
