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
sed -i 's|^http {|http {\n    limit_req_zone $binary_remote_addr zone=perclient:10m rate=5r/s;|' /etc/nginx/nginx.conf
sed -i 's|    index index.html;|    index index.html;\n    limit_req zone=perclient burst=5 nodelay;|' /etc/nginx/conf.d/shop.conf
systemctl enable --now nginx
