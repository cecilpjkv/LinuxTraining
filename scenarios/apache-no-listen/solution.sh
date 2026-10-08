# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/^#Listen 80/Listen 80/' /etc/httpd/conf/httpd.conf
systemctl restart httpd
