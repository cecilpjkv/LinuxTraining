#!/bin/bash
set -e
grep -q 'app.example.test' /etc/hosts || echo '127.0.0.1 app.example.test' >> /etc/hosts
cat > /etc/nginx/conf.d/app.conf <<'CONF'
server {
    listen 80;
    server_name app.example.test;
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
CONF
systemctl enable --now nginx
