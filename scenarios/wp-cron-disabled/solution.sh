# reference fix (not imported; used by scripts/check_scenarios.py)
echo '*/5 * * * * apache /usr/bin/php /usr/local/bin/wp --path=/srv/www/wp cron event run --due-now --quiet' > /etc/cron.d/wordpress
