# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's|^#LoadModule rewrite_module|LoadModule rewrite_module|' /etc/httpd/conf.modules.d/00-base.conf
systemctl restart httpd
