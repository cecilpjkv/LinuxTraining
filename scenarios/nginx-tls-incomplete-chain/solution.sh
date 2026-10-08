# reference fix (not imported; used by scripts/check_scenarios.py)
cat /etc/pki/shop/shop.crt /etc/pki/shop/intermediate.crt > /etc/pki/shop/shop.chain.crt
sed -i 's|/etc/pki/shop/shop.crt;|/etc/pki/shop/shop.chain.crt;|' /etc/nginx/conf.d/shop.conf
systemctl reload nginx
