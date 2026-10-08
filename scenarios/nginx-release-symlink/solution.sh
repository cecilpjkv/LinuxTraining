# reference fix (not imported; used by scripts/check_scenarios.py)
ln -sfn /srv/www/releases/2024-10-07 /srv/www/current
sed -i 's/    disable_symlinks on;/    disable_symlinks if_not_owner;/' /etc/nginx/conf.d/shop.conf
systemctl reload nginx
