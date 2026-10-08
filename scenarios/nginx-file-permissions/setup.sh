#!/bin/bash
set -e
mkdir -p /srv/www/shop
cat > /srv/www/shop/index.html <<'HTML'
<!doctype html><title>Example Shop</title><h1>Example Shop</h1><p>Shop OK</p>
HTML
grep -q 'shop.example.test' /etc/hosts || echo '127.0.0.1 shop.example.test blog.example.test api.example.test portal.example.test' >> /etc/hosts
cat > /etc/nginx/conf.d/shop.conf <<'CONF'
server {
    listen 80;
    server_name shop.example.test;
    root /srv/www/shop;
    index index.html;
}
CONF
mkdir -p /srv/www/shop/img
printf 'PNG-LOGO' > /srv/www/shop/img/logo.png
systemctl enable --now nginx
# the restore: root with umask 077
chown -R root:root /srv/www/shop
find /srv/www/shop -type d -exec chmod 700 {} +
find /srv/www/shop -type f -exec chmod 600 {} +
curl -s -o /dev/null -H 'Host: shop.example.test' http://127.0.0.1/
