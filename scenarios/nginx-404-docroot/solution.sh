# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's|root /srv/www/shop/public;|root /srv/www/shop/current/public;|' /etc/nginx/conf.d/shop.conf
systemctl reload nginx
