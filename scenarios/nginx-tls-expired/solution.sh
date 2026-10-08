# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's|/etc/pki/shop/shop.crt;|/etc/pki/shop/2025-renewal/shop.fullchain.crt;|; s|/etc/pki/shop/shop.key;|/etc/pki/shop/2025-renewal/shop.key;|' /etc/nginx/conf.d/shop.conf
systemctl reload nginx
