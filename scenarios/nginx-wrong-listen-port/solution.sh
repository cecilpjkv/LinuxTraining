# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/    listen 8080;/    listen 80;/' /etc/nginx/conf.d/shop.conf
systemctl reload nginx
