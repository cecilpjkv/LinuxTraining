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
sed -i 's|    DocumentRoot /srv/www/portal|    DocumentRoot /srv/www/portal\n    RewriteEngine On\n    RewriteRule ^/home$ /index.html [PT]|' /etc/httpd/conf.d/portal.conf
systemctl enable --now httpd
sed -i 's|^LoadModule rewrite_module|#LoadModule rewrite_module|' /etc/httpd/conf.modules.d/00-base.conf
systemctl restart httpd || true
