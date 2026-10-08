# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/^user webuser;/user nginx;/' /etc/nginx/nginx.conf
systemctl restart nginx
