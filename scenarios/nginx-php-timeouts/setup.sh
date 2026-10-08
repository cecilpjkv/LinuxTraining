#!/bin/bash
set -e
grep -q 'shop.example.test' /etc/hosts || echo '127.0.0.1 shop.example.test blog.example.test api.example.test portal.example.test' >> /etc/hosts
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
printf '<?php sleep(8); echo "EXPORT-DONE\\n";\n' > /srv/www/shop/export.php
sed -i 's|        fastcgi_index index.php;|        fastcgi_index index.php;\n        fastcgi_read_timeout 5s;|' /etc/nginx/conf.d/shop.conf
printf 'max_execution_time = 6\n' > /etc/php.d/90-limits.ini
printf 'php_admin_value[max_execution_time] = 6\n' >> /etc/php-fpm.d/www.conf
systemctl enable --now php-fpm nginx
for i in $(seq 1 20); do [ -S /run/php-fpm/www.sock ] && break; sleep 0.5; done
curl -s -o /dev/null -H 'Host: shop.example.test' http://127.0.0.1/
