# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/^pm.start_servers = .*/pm.start_servers = 5/' /etc/php-fpm.d/www.conf
systemctl restart php-fpm
sleep 1
