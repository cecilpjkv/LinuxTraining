# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's|    AllowOverride None|    AllowOverride FileInfo|' /etc/httpd/conf.d/portal.conf
systemctl reload httpd
