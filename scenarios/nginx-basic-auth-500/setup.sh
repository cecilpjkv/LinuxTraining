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
mkdir -p /srv/www/shop/admin && echo 'ADMIN-AREA' > /srv/www/shop/admin/index.html
htpasswd -bc /etc/nginx/.htpasswd staff Staff-Pass-1 2>/dev/null
sed -i 's|    index index.html;|    index index.html;\n    location /admin/ {\n        auth_basic "Staff only";\n        auth_basic_user_file /etc/nginx/.htpasswd;\n    }|' /etc/nginx/conf.d/shop.conf
chown root:root /etc/nginx/.htpasswd; chmod 600 /etc/nginx/.htpasswd
systemctl enable --now nginx
