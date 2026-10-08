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
cat > /srv/www/shop/upload.php <<'PHP'
<?php
if ($_SERVER['REQUEST_METHOD'] !== 'POST') { echo "send a file\n"; exit; }
$f = $_FILES['file'] ?? null;
if (!$f) { http_response_code(400); echo "UPLOAD FAILED: no file (post_max_size?)\n"; exit; }
if ($f['error'] !== UPLOAD_ERR_OK) { http_response_code(400); echo "UPLOAD FAILED: error code " . $f['error'] . "\n"; exit; }
echo "UPLOAD OK " . $f['size'] . "\n";
PHP
sed -i 's|    index index.php;|    index index.php;\n    client_max_body_size 1m;|' /etc/nginx/conf.d/shop.conf
printf '; shop settings\nupload_max_filesize = 2M\npost_max_size = 2M\n' > /etc/php.d/99-shop.ini
printf 'php_admin_value[upload_max_filesize] = 1M\n' >> /etc/php-fpm.d/www.conf
systemctl enable --now php-fpm nginx
for i in $(seq 1 20); do [ -S /run/php-fpm/www.sock ] && break; sleep 0.5; done
curl -s -o /dev/null -H 'Host: shop.example.test' http://127.0.0.1/
