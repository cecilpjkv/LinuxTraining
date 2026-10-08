# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i "s/define( 'DB_PASSWORD', 'Old-Server-Pass' );/define( 'DB_PASSWORD', 'Wp-Pass-2024' );/" /srv/www/wp/wp-config.php
mysql wordpress </dev/null -e "UPDATE wp_options SET option_value='http://wp.example.test' WHERE option_name IN ('home','siteurl')"
sed -i 's|    location / { try_files $uri $uri/ =404; }|    location / { try_files $uri $uri/ /index.php?$args; }|' /etc/nginx/conf.d/wp.conf
chown -R apache:apache /srv/www/wp/wp-content/uploads
systemctl reload nginx
