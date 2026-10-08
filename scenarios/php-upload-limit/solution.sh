# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/client_max_body_size 1m;/client_max_body_size 10m;/' /etc/nginx/conf.d/shop.conf
sed -i 's/^upload_max_filesize = 2M/upload_max_filesize = 10M/; s/^post_max_size = 2M/post_max_size = 12M/' /etc/php.d/99-shop.ini
sed -i 's/^php_admin_value\[upload_max_filesize\] = 1M/php_admin_value[upload_max_filesize] = 10M/' /etc/php-fpm.d/www.conf
systemctl restart php-fpm
systemctl reload nginx
sleep 1
