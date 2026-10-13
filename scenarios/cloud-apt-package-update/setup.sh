#!/bin/bash
set -e
grep -q 'www.example.test' /etc/hosts || echo '127.0.0.1 www.example.test' >> /etc/hosts
mkdir -p /var/www/example
echo '<!doctype html><title>Example</title><h1>Example Ltd</h1><p>Site OK</p>' > /var/www/example/index.html
cat > /etc/nginx/sites-available/example <<'CONF'
server {
    listen 80;
    server_name www.example.test;
    root /var/www/example;
    access_log /var/log/nginx/example.access.log;
}
CONF
ln -sf /etc/nginx/sites-available/example /etc/nginx/sites-enabled/example
systemctl enable --now nginx
curl -s -o /dev/null -H 'Host: www.example.test' http://127.0.0.1/
dpkg-query -W -f='${Version}' openssl > /var/lib/.lt-openssl
