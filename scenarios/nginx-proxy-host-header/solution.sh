# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's|        proxy_pass http://orders;|        proxy_pass http://orders;\n        proxy_set_header Host $host;|' /etc/nginx/conf.d/api.conf
systemctl reload nginx
