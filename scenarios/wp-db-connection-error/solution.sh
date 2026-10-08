# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i "s/define( 'DB_HOST', 'locahost' );/define( 'DB_HOST', 'localhost' );/" /srv/www/wp/wp-config.php
