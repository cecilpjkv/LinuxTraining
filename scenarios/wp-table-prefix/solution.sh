# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i "s/^\$table_prefix = 'wp2_';/\$table_prefix = 'wp_';/" /srv/www/wp/wp-config.php
