# reference fix (not imported; used by scripts/check_scenarios.py)
WP="wp --allow-root --path=/srv/www/wp"
$WP config set WP_DEBUG true --raw --quiet
$WP config set WP_DEBUG_LOG true --raw --quiet
$WP config set WP_DEBUG_DISPLAY false --raw --quiet
$WP cron event schedule shop_cleanup_carts now hourly --quiet
echo '*/5 * * * * apache /usr/bin/php /usr/local/bin/wp --path=/srv/www/wp cron event run --due-now --quiet' > /etc/cron.d/wordpress
runuser -u apache -- /usr/bin/php /usr/local/bin/wp --path=/srv/www/wp cron event run --due-now --quiet
