#!/bin/bash
set -e
grep -q 'shop.example.test' /etc/hosts || echo '127.0.0.1 shop.example.test blog.example.test api.example.test portal.example.test' >> /etc/hosts
mkdir -p /srv/www/shop/catalog
printf '<?php echo "<h1>Shop</h1><p>PHP-OK-" . (40 + 2) . "</p>";\n' > /srv/www/shop/index.php
printf '<?php echo "CATALOG-OK";\n' > /srv/www/shop/catalog/index.php
printf '<?php $secret = "Leaked-Key-123";\n' > /srv/www/shop/settings.php
chown -R apache:apache /srv/www/shop; chmod 700 /srv/www/shop/catalog
printf 'server {\n    listen 80;\n    server_name shop.example.test;\n    root /srv/www/shop;\n    index index.php;\n}\n' > /etc/nginx/conf.d/shop.conf
echo '<VirtualHost *:80>
    ServerName shop.example.test
    DocumentRoot /srv/www/shop
</VirtualHost>' > /etc/httpd/conf.d/shop.conf
systemctl enable httpd nginx php-fpm
systemctl start php-fpm nginx
