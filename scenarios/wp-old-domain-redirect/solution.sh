# reference fix (not imported; used by scripts/check_scenarios.py)
WP='wp --allow-root --path=/srv/www/wp'; $WP option update home 'http://wp.example.test' --quiet </dev/null; $WP option update siteurl 'http://wp.example.test' --quiet </dev/null
