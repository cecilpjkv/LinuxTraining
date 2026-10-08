#!/bin/bash
set -e
grep -q 'shop.example.test' /etc/hosts || echo '127.0.0.1 shop.example.test' >> /etc/hosts
mkdir -p /srv/www/shop
cat > /srv/www/shop/index.php <<'PHP'
<?php echo "<h1>Example Shop</h1><p>PHP-OK-" . (40 + 2) . "</p>\n";
PHP
cat > /etc/nginx/conf.d/shop.conf <<'CONF'
server {
    listen 80;
    server_name shop.example.test;
    root /srv/www/shop;
    index index.php;
    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
CONF
systemctl enable --now php-fpm nginx
for i in $(seq 1 20); do [ -S /run/php-fpm/www.sock ] && break; sleep 0.5; done
curl -s -o /dev/null -H 'Host: shop.example.test' http://127.0.0.1/
sed -i 's|^listen = /run/php-fpm/www.sock|; renamed to match the site (ticket 5120)\nlisten = /run/php-fpm/shop.sock|' /etc/php-fpm.d/www.conf
systemctl restart php-fpm
curl -s -o /dev/null -H 'Host: shop.example.test' http://127.0.0.1/
