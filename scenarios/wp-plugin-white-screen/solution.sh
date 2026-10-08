# reference fix (not imported; used by scripts/check_scenarios.py)
WP='wp --allow-root --path=/srv/www/wp'; $WP plugin deactivate shop-tweaks --skip-plugins=shop-tweaks --quiet </dev/null || mv /srv/www/wp/wp-content/plugins/shop-tweaks /srv/www/wp/wp-content/plugins/shop-tweaks.disabled
