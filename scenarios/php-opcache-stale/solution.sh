# reference fix: let opcache re-check changed files, then reload php-fpm so it takes effect
cat > /etc/php.d/90-opcache.ini <<'INI'
opcache.enable=1
opcache.validate_timestamps=1
opcache.revalidate_freq=0
INI
systemctl reload php-fpm || systemctl restart php-fpm
sleep 2
