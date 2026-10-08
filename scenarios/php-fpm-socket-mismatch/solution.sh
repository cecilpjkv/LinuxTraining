# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's|^listen = /run/php-fpm/shop.sock|listen = /run/php-fpm/www.sock|' /etc/php-fpm.d/www.conf
systemctl restart php-fpm
sleep 1
