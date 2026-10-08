# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's|    location / { try_files $uri $uri/ =404; }|    location / { try_files $uri $uri/ /index.php?$args; }|' /etc/nginx/conf.d/wp.conf
systemctl reload nginx
