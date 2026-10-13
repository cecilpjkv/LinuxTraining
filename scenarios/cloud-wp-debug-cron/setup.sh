#!/bin/bash
set -e
grep -q 'wp.example.test' /etc/hosts || echo '127.0.0.1 wp.example.test' >> /etc/hosts
systemctl enable --now mariadb
for i in $(seq 1 30); do mysqladmin ping >/dev/null 2>&1 </dev/null && break; sleep 1; done
mysql </dev/null -e "CREATE DATABASE IF NOT EXISTS wordpress; CREATE USER IF NOT EXISTS 'wpuser'@'localhost' IDENTIFIED BY 'Wp-Pass-2024'; GRANT ALL ON wordpress.* TO 'wpuser'@'localhost'; FLUSH PRIVILEGES;"
mkdir -p /srv/www && cp -a /opt/wordpress /srv/www/wp
cat > /etc/nginx/conf.d/wp.conf <<'CONF'
server {
    listen 80;
    server_name wp.example.test;
    root /srv/www/wp;
    index index.php;
    location / { try_files $uri $uri/ /index.php?$args; }
    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
CONF
WP="wp --allow-root --path=/srv/www/wp"
sed -e "s/database_name_here/wordpress/" -e "s/username_here/wpuser/" -e "s/password_here/Wp-Pass-2024/" \
    /srv/www/wp/wp-config-sample.php > /srv/www/wp/wp-config.php
php -r '$f="/srv/www/wp/wp-config.php"; $c=file_get_contents($f); $c=preg_replace_callback("/put your unique phrase here/", fn() => bin2hex(random_bytes(24)), $c); file_put_contents($f, $c);'
$WP core install --url=http://wp.example.test --title="Training Shop" --admin_user=wpadmin --admin_password=Wp-Admin-Pass-1 --admin_email=admin@example.test --skip-email --quiet </dev/null
$WP rewrite structure '/%postname%/' --quiet </dev/null
$WP post create --post_title="Hello Training" --post_name=hello-training --post_status=publish --post_content="WP-POST-OK" --quiet </dev/null
# the shop plugin's helpers (a must-use plugin)
mkdir -p /srv/www/wp/wp-content/mu-plugins
cat > /srv/www/wp/wp-content/mu-plugins/shop-tools.php <<'PHP'
<?php
/* Plugin Name: Shop tools */
add_action('shop_cleanup_carts', function () {
    update_option('shop_cleanup_last_run', time());
});
add_action('shop_cron_probe', function ($tag) {
    update_option('shop_cron_probe_' . $tag, time());
});
add_action('init', function () {
    if (isset($_GET['shop_debug_test'])) {
        trigger_error('Shop debug test ' . preg_replace('/[^A-Za-z0-9-]/', '', $_GET['shop_debug_test']), E_USER_NOTICE);
    }
});
PHP
sed -i "s|/\* That's all, stop editing! Happy publishing. \*/|define( 'DISABLE_WP_CRON', true );\n/* That's all, stop editing! Happy publishing. */|" /srv/www/wp/wp-config.php
chown -R apache:apache /srv/www/wp
# like most hosts: no pool-level error_log, so WordPress decides where PHP's errors go
sed -i 's/^php_admin_value\[error_log\]/;&/' /etc/php-fpm.d/www.conf
systemctl enable --now php-fpm nginx
for i in $(seq 1 20); do [ -S /run/php-fpm/www.sock ] && break; sleep 0.5; done
curl -s -o /dev/null -H 'Host: wp.example.test' http://127.0.0.1/
