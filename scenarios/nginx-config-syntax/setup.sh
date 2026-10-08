#!/bin/bash
# The site works, then a colleague's edit (a missing semicolon) breaks the configuration and a restart takes nginx down.
set -e
mkdir -p /srv/www/shop
cat > /srv/www/shop/index.html <<'HTML'
<!doctype html><title>Example Shop</title><h1>Example Shop</h1><p>Shop OK</p>
HTML
echo '127.0.0.1 shop.example.test' >> /etc/hosts
cat > /etc/nginx/conf.d/shop.conf <<'CONF'
server {
    listen 80;
    server_name shop.example.test;
    root /srv/www/shop;
    index index.html;
    access_log /var/log/nginx/shop_access.log;
    error_log /var/log/nginx/shop_error.log;
}
CONF
systemctl enable --now nginx
curl -fsS -o /dev/null -H 'Host: shop.example.test' http://127.0.0.1/
for i in 1 2 3; do curl -s -o /dev/null -H 'Host: shop.example.test' http://127.0.0.1/; done
# the colleague's change: a new header line without its semicolon
sed -i 's|^    index index.html;|    index index.html;\n    add_header X-Shop-Version "2.4"\n    expires 1h;|' /etc/nginx/conf.d/shop.conf
systemctl restart nginx || true
