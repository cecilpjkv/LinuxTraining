#!/bin/bash
set -e
grep -q 'shop2.example.test' /etc/hosts || echo '127.0.0.1 shop2.example.test' >> /etc/hosts
mkdir -p /srv/www/shop2
cat > /srv/www/shop2/index.php <<'PHP'
<?php
echo "RELEASE-1\n";
PHP
chown -R apache:apache /srv/www/shop2
# production-style opcache: never re-check files on disk (the fault to fix)
cat > /etc/php.d/90-opcache.ini <<'INI'
opcache.enable=1
opcache.validate_timestamps=0
opcache.revalidate_freq=0
INI
cat > /etc/nginx/conf.d/shop2.conf <<'CONF'
server {
    listen 80 default_server;
    server_name shop2.example.test;
    root /srv/www/shop2;
    index index.php;
    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
CONF
systemctl enable --now php-fpm nginx
for i in $(seq 1 20); do [ -S /run/php-fpm/www.sock ] && break; sleep 0.5; done
# let the file age past opcache.file_update_protection (2s), then warm the cache with RELEASE-1
sleep 3
curl -s -o /dev/null -H 'Host: shop2.example.test' http://127.0.0.1/
# the "deploy": the file is updated on disk, but opcache keeps serving RELEASE-1
cat > /srv/www/shop2/index.php <<'PHP'
<?php
echo "RELEASE-2\n";
PHP
chown apache:apache /srv/www/shop2/index.php
