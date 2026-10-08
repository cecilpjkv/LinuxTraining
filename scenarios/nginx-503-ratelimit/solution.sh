# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/rate=1r\/m;/rate=20r\/s;/' /etc/nginx/nginx.conf
sed -i 's/limit_req zone=perip;/limit_req zone=perip burst=40 nodelay;/' /etc/nginx/conf.d/shop.conf
systemctl reload nginx
