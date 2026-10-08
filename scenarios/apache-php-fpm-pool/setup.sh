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
id portal >/dev/null 2>&1 || useradd -r -s /sbin/nologin portal
printf '<?php echo "PHP-OK-" . (40 + 2) . " as " . get_current_user();\n' > /srv/www/portal/status.php
chown -R root:root /srv/www/portal; chmod 750 /srv/www/portal; chmod 640 /srv/www/portal/status.php
cat > /etc/php-fpm.d/portal.conf.disabled <<'X'
[portal]
user = portal
group = portal
listen = /run/php-fpm/portal.sock
listen.owner = apache
listen.group = apache
listen.mode = 0660
pm = ondemand
pm.max_children = 5
X
sed -i 's|</VirtualHost>|    <FilesMatch "\\.php$">\n        SetHandler "proxy:unix:/run/php-fpm/portal.sock\|fcgi://localhost"\n    </FilesMatch>\n</VirtualHost>|' /etc/httpd/conf.d/portal.conf
systemctl enable --now php-fpm httpd
