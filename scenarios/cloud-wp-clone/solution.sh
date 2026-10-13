# reference fix (not imported; used by scripts/check_scenarios.py)
cp -a /srv/www/wp /srv/www/staging
mysql -e "CREATE DATABASE wp_staging; CREATE USER 'wpstaging'@'localhost' IDENTIFIED BY 'Staging-Pass-9'; GRANT ALL ON wp_staging.* TO 'wpstaging'@'localhost'"
mysqldump wordpress | mysql wp_staging
WP="wp --allow-root --path=/srv/www/staging"
$WP config set DB_NAME wp_staging --quiet
$WP config set DB_USER wpstaging --quiet
$WP config set DB_PASSWORD Staging-Pass-9 --quiet
$WP search-replace http://wp.example.test http://staging.example.test --all-tables --quiet
sed -e 's/server_name wp.example.test/server_name staging.example.test/' -e 's#root /srv/www/wp#root /srv/www/staging#' /etc/nginx/conf.d/wp.conf > /etc/nginx/conf.d/staging.conf
systemctl reload nginx
