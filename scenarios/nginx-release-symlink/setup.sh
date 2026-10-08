#!/bin/bash
set -e
grep -q 'shop.example.test' /etc/hosts || echo '127.0.0.1 shop.example.test blog.example.test api.example.test portal.example.test' >> /etc/hosts
for r in 2024-09-30 2024-10-07; do mkdir -p /srv/www/releases/$r; echo "<h1>Shop</h1><p>RELEASE-$r</p>" > /srv/www/releases/$r/index.html; done
mkdir -p /srv/www/releases/2024-10-08 && echo 'x' > /srv/www/releases/2024-10-08/index.html
ln -sfn /srv/www/releases/2024-10-08 /srv/www/current
printf 'server {\n    listen 80;\n    server_name shop.example.test;\n    root /srv/www/current;\n    index index.html;\n    disable_symlinks on;\n}\n' > /etc/nginx/conf.d/shop.conf
systemctl enable --now nginx
rm -rf /srv/www/releases/2024-10-08
