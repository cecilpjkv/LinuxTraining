# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's|        fastcgi_index index.php$|        fastcgi_index index.php;|' /etc/nginx/conf.d/shop.conf
sed -i 's|^listen = /run/php-fpm/shop.sock|listen = /run/php-fpm/www.sock|' /etc/php-fpm.d/www.conf
sed -i "s/^\$DB_PASS = .*/\$DB_PASS = 'Rotated-Shop-77a1!';/" /srv/www/shop/config.php
systemctl restart php-fpm nginx
