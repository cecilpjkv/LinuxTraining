# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i "s/^\$DB_HOST = 'localhost';/\$DB_HOST = '127.0.0.1';/" /srv/www/shop/config.php
