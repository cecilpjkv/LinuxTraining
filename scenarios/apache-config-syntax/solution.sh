# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/    DocumentRooot /    DocumentRoot /' /etc/httpd/conf.d/portal.conf
systemctl restart httpd
