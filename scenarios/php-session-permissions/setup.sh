#!/bin/bash
set -e
grep -q 'portal.example.test' /etc/hosts || echo '127.0.0.1 portal.example.test' >> /etc/hosts
mkdir -p /srv/www/portal
cat > /srv/www/portal/index.php <<'PHP'
<?php
session_start();
$_SESSION['n'] = (isset($_SESSION['n']) ? $_SESSION['n'] : 0) + 1;
echo "COUNT=" . $_SESSION['n'] . "\n";
PHP
chown -R apache:apache /srv/www/portal
cat > /etc/nginx/conf.d/portal.conf <<'CONF'
server {
    listen 80 default_server;
    server_name portal.example.test;
    root /srv/www/portal;
    index index.php;
    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
CONF
systemctl enable --now php-fpm nginx
for i in $(seq 1 20); do [ -S /run/php-fpm/www.sock ] && break; sleep 0.5; done
# the break: the PHP session directory (used by the php-fpm pool) is no longer writable
# by the php-fpm user, so sessions cannot be stored
S=/var/lib/php/session
chown root:root "$S"
chmod 700 "$S"
rm -f "$S"/sess_* 2>/dev/null || true
