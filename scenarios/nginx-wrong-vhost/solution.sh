# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/exmaple/example/g' /etc/nginx/conf.d/blog.conf
systemctl reload nginx
