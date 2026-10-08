# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/^pm.max_children = 1$/pm.max_children = 8/; s/^request_terminate_timeout = 2s/request_terminate_timeout = 60s/' /etc/php-fpm.d/www.conf
systemctl restart php-fpm
sleep 1
