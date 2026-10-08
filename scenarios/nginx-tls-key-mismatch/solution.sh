# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's|/etc/pki/shop/shop-2023.key;|/etc/pki/shop/shop.key;|' /etc/nginx/conf.d/shop.conf
systemctl restart nginx
