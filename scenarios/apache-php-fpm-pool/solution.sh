# reference fix (not imported; used by scripts/check_scenarios.py)
mv /etc/php-fpm.d/portal.conf.disabled /etc/php-fpm.d/portal.conf
chown -R portal:apache /srv/www/portal
chmod 750 /srv/www/portal; chmod 640 /srv/www/portal/*
systemctl restart php-fpm
