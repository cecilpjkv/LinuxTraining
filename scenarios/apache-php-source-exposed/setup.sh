#!/bin/bash
set -e
mkdir -p /srv/www/portal
echo '<!doctype html><title>Portal</title><h1>Customer Portal</h1><p>Portal OK</p>' > /srv/www/portal/index.html
grep -q 'portal.example.test' /etc/hosts || echo '127.0.0.1 portal.example.test' >> /etc/hosts
cat > /etc/httpd/conf.d/portal.conf <<'CONF'
<VirtualHost *:80>
    ServerName portal.example.test
    DocumentRoot /srv/www/portal
    ErrorLog /var/log/httpd/portal_error.log
    CustomLog /var/log/httpd/portal_access.log combined
</VirtualHost>
<Directory /srv/www/portal>
    Require all granted
</Directory>
CONF
printf '<?php\n$db_password = "Portal-DB-Secret";\n' > /srv/www/portal/config.php
printf '<?php require "config.php"; echo "PHP-OK-" . (40 + 2);\n' > /srv/www/portal/status.php
mv /etc/httpd/conf.d/php.conf /etc/httpd/conf.d/php.conf.unused
systemctl enable --now httpd
