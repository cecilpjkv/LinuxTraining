#!/bin/bash
set -e
grep -q 'shop.example.test' /etc/hosts || echo '127.0.0.1 shop.example.test' >> /etc/hosts
mkdir -p /srv/shop/account /srv/shop/api
echo '<!doctype html><title>Shop</title><h1>Example Shop</h1><p>Shop home</p>' > /srv/shop/index.html
echo '<!doctype html><title>My account</title><h1>Your account</h1>' > /srv/shop/account/index.html
echo '{"blue-mug": 12, "red-mug": 0}' > /srv/shop/api/stock
cat > /etc/nginx/conf.d/shop.conf <<'CONF'
# page cache in front of the shop application (the application listens on 127.0.0.1:8080)
proxy_cache_path /var/cache/nginx/shop levels=1:2 keys_zone=shop:10m max_size=200m inactive=60m;

map $cookie_shop_session $shop_logged_in {
    default 1;
    ""      0;
}

server {
    listen 80;
    server_name shop.example.test;

    proxy_cache shop;
    proxy_cache_valid 200 301 10m;
    proxy_cache_bypass $shop_logged_in;   # logged-in customers see their own cart: never from the cache
    proxy_no_cache $shop_logged_in;
    add_header X-Cache-Status $upstream_cache_status always;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
    }
    location /account/ {
        proxy_cache_bypass 1;              # personal pages
        proxy_no_cache 1;
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
    }
}

# the "application"
server {
    listen 127.0.0.1:8080;
    server_name shop.example.test;
    root /srv/shop;
    location / { add_header Cache-Control "public, max-age=600"; }
    location = /api/stock { default_type application/json; add_header Cache-Control "private, no-store"; }
}
CONF
mkdir -p /var/cache/nginx/shop && chown nginx /var/cache/nginx/shop
systemctl enable --now nginx
md5sum /etc/nginx/conf.d/shop.conf | cut -d' ' -f1 > /var/lib/.lt-shop-conf
cat > /root/answers.txt <<'TXT'
# Cache check for shop.example.test. Fill in each value after the "=" (one line each).
home_repeat_status=
account_status=
account_reason=
logged_in_status=
logged_in_reason=
stock_status=
stock_reason=
TXT
