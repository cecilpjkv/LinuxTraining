# reference fix: restore the application's own files, delete the payload
cp -a /root/.lt-clean/. /srv/www/portal/
rm -f /srv/www/portal/inc/.query.php
chown -R apache:apache /srv/www/portal
