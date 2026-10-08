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
mkdir -p /srv/www/shop/assets
echo '<!doctype html><title>Shop App</title><div id=app>SPA-SHELL</div><script src=/assets/app.js></script>' > /srv/www/shop/index.html
echo 'console.log("APP-JS")' > /srv/www/shop/assets/app.js
systemctl enable --now nginx
