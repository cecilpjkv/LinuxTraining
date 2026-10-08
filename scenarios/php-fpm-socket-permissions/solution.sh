# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/^listen.owner = apache/listen.owner = nginx/; s/^listen.group = apache/listen.group = nginx/' /etc/php-fpm.d/www.conf
systemctl restart php-fpm
sleep 1
