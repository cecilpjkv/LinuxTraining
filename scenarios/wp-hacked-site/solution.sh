# reference fix (not imported; used by scripts/check_scenarios.py)
T=$(cat /root/.lt-theme); cp /root/.lt-functions.orig $T/functions.php; chown apache: $T/functions.php
rm -f /srv/www/wp/wp-content/uploads/2024/10/cache.php
wp --allow-root --path=/srv/www/wp user delete wpsupport --reassign=1 --yes --quiet </dev/null
sed -i 's|    location / { try_files|    location ~* ^/wp-content/uploads/.*\\.php$ { deny all; }\n    location / { try_files|' /etc/nginx/conf.d/wp.conf
systemctl reload nginx
