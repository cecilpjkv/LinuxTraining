# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's|    ServerName portal.example.com|    ServerName portal.example.test\n    SSLEngine on|' /etc/httpd/conf.d/zz-portal-ssl.conf
systemctl reload httpd
