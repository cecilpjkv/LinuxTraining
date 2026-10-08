# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/proxy_cache_valid 200 1d;/proxy_cache_valid 200 2m;/' /etc/nginx/conf.d/shop.conf
rm -rf /var/cache/nginx/shop/*
systemctl reload nginx
