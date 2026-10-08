#!/bin/bash
set -e
mkdir -p /srv/www/shop
cat > /srv/www/shop/index.html <<'HTML'
<!doctype html><title>Example Shop</title><h1>Example Shop</h1><p>Shop OK</p>
HTML
grep -q 'shop.example.test' /etc/hosts || echo '127.0.0.1 shop.example.test blog.example.test api.example.test portal.example.test' >> /etc/hosts
mkdir -p /srv/www/shop/current/public/img
mv /srv/www/shop/index.html /srv/www/shop/current/public/
printf 'PNG-LOGO' > /srv/www/shop/current/public/img/logo.png
cat > /etc/nginx/conf.d/shop.conf <<'CONF'
server {
    listen 80;
    server_name shop.example.test;
    root /srv/www/shop/public;
    index index.html;
}
CONF
systemctl enable --now nginx
