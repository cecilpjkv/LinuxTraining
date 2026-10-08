# reference fix (not imported; used by scripts/check_scenarios.py)
systemctl disable --now nginx
sed -i '/^Listen 0.0.0.0:80$/d' /etc/httpd/conf.d/portal.conf
systemctl restart httpd
