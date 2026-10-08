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
sed -i 's/    listen 80;/    listen 80 default_server;/' /etc/nginx/conf.d/shop.conf
# nginx.conf's own catch-all server would clash with the shop's default_server
python3 - <<'PY'
import re
p = "/etc/nginx/nginx.conf"
s = open(p).read()
s = s.replace("listen       80;", "listen       8080;").replace("listen       [::]:80;", "listen       [::]:8080;")
open(p, "w").write(s)
PY
mkdir -p /srv/www/blog
echo '<!doctype html><title>Blog</title><h1>Company Blog</h1><p>Blog OK</p>' > /srv/www/blog/index.html
cat > /etc/nginx/conf.d/blog.conf <<'CONF'
server {
    listen 80;
    server_name blog.exmaple.test www.blog.exmaple.test;
    root /srv/www/blog;
    index index.html;
}
CONF
systemctl enable --now nginx
