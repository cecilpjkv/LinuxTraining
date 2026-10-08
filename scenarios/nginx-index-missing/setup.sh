#!/bin/bash
set -e
grep -q 'shop.example.test' /etc/hosts || echo '127.0.0.1 shop.example.test blog.example.test api.example.test portal.example.test' >> /etc/hosts
mkdir -p /srv/www/shop
cat > /srv/www/shop/index.html <<'HTML'
<!doctype html><title>Example Shop</title><h1>Example Shop</h1><p>Shop OK</p>
HTML
cat > /etc/nginx/conf.d/shop.conf <<'CONF'
server {
    listen 80;
    server_name shop.example.test;
    root /srv/www/shop;
    index index.html;
}
CONF
mkdir -p /srv/www/shop/img && printf 'PNG' > /srv/www/shop/img/logo.png
cp -a /srv/www/shop /srv/www/shop.previous
rm -f /srv/www/shop/index.html
systemctl enable --now nginx
