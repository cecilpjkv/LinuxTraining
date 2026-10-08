# reference fix (not imported; used by scripts/check_scenarios.py)
cat > /etc/nginx/conf.d/shop.conf <<'CONF'
server {
    listen 80;
    server_name shop.example.test;
    return 301 https://$host$request_uri;
}
server {
    listen 443 ssl;
    server_name shop.example.test;
    ssl_certificate     /etc/pki/shop/shop.fullchain.crt;
    ssl_certificate_key /etc/pki/shop/shop.key;
    root /srv/www/shop;
    index index.html;
}
CONF
systemctl restart nginx
