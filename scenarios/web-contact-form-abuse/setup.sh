#!/bin/bash
set -e
mkdir -p /srv/www/help /var/log/app
# a fake MTA: records the envelope (recipients) and the message (headers+body) instead of really sending
cat > /usr/local/sbin/lt-sendmail <<'MTA'
#!/bin/bash
# usage like sendmail: recipients are the arguments; message (headers+body) on stdin
{ echo "=== $(date -u +%FT%TZ) RCPT: $*"; cat; echo; } >> /var/log/app/mail.log
MTA
chmod 755 /usr/local/sbin/lt-sendmail
: > /var/log/app/mail.log
chown -R apache:apache /var/log/app
# point PHP at the fake MTA
echo 'sendmail_path = "/usr/local/sbin/lt-sendmail -t -i"' > /etc/php.d/99-lt-sendmail.ini

# the vulnerable contact form: recipient and headers come straight from the request
cat > /srv/www/help/contact.php <<'PHP'
<?php
$to      = isset($_POST['to']) ? $_POST['to'] : 'owner@help.example.test';
$from    = isset($_POST['email']) ? $_POST['email'] : 'anon@example';
$message = isset($_POST['message']) ? $_POST['message'] : '';
$headers = "From: $from\r\nReply-To: $from\r\n";
mail($to, 'Website contact', $message, $headers);
echo "SENT-OK";
PHP
chown -R apache:apache /srv/www/help

cat > /etc/nginx/conf.d/help.conf <<'CONF'
server {
    listen 80 default_server;
    server_name www.help.example.test;
    root /srv/www/help;
    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
CONF
systemctl enable --now php-fpm nginx
for i in $(seq 1 20); do [ -S /run/php-fpm/www.sock ] && break; sleep 0.5; done
cp /srv/www/help/contact.php /root/.lt-contact.orig
