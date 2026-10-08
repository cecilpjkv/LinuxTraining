#!/bin/bash
set -e
grep -q 'wp.example.test' /etc/hosts || echo '127.0.0.1 wp.example.test www.wp-old.example.test' >> /etc/hosts
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
    client_max_body_size 32m;
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
$WP core install --url=http://wp.example.test --title="Training Blog" --admin_user=wpadmin --admin_password=Wp-Admin-Pass-1 --admin_email=admin@example.test --skip-email --quiet </dev/null
$WP rewrite structure '/%postname%/' --quiet </dev/null
$WP post create --post_title="Hello Training" --post_name=hello-training --post_status=publish --post_content="WP-POST-OK" --quiet </dev/null
chown -R apache:apache /srv/www/wp
systemctl enable --now php-fpm nginx
for i in $(seq 1 20); do [ -S /run/php-fpm/www.sock ] && break; sleep 0.5; done
curl -s -o /dev/null -H 'Host: wp.example.test' http://127.0.0.1/
mkdir -p /etc/pki/wp
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout /etc/pki/wp/wp.key -out /etc/pki/wp/wp.crt -days 365 -subj "/CN=wp.example.test" -addext "subjectAltName=DNS:wp.example.test" 2>/dev/null
sed -i 's|    listen 80;|    listen 127.0.0.1:8080;|' /etc/nginx/conf.d/wp.conf
cat > /etc/nginx/conf.d/wp-tls.conf <<'CONF'
server {
    listen 443 ssl;
    server_name wp.example.test;
    ssl_certificate /etc/pki/wp/wp.crt;
    ssl_certificate_key /etc/pki/wp/wp.key;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
    }
}
CONF
$WP option update home 'https://wp.example.test' --quiet </dev/null
$WP option update siteurl 'https://wp.example.test' --quiet </dev/null
systemctl reload nginx
