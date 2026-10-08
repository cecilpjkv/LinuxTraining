# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/    index index.htm;/    index index.html;/' /etc/nginx/conf.d/shop.conf
systemctl reload nginx
