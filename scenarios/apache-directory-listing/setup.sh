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
mkdir -p /srv/www/portal/files && echo 'BROCHURE' > /srv/www/portal/files/brochure.txt
echo 'INSERT INTO customers VALUES (1, "secret");' > /srv/www/portal/files/portal-backup-2024.sql
sed -i 's|<Directory /srv/www/portal>|<Directory /srv/www/portal>\n    Options Indexes FollowSymLinks|' /etc/httpd/conf.d/portal.conf
systemctl enable --now httpd
