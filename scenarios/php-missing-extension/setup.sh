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
cat > /srv/www/shop/index.php <<'PHP'
<?php
echo "<h1>" . mb_strtoupper("example shop ünïcode") . "</h1><p>PHP-OK-" . (40 + 2) . "</p>\n";
PHP
sha256sum /srv/www/shop/index.php > /root/.lt-code.sha256
systemctl enable --now php-fpm nginx
for i in $(seq 1 20); do [ -S /run/php-fpm/www.sock ] && break; sleep 0.5; done
curl -s -o /dev/null -H 'Host: shop.example.test' http://127.0.0.1/
