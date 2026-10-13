#!/bin/bash
set -e
if [ "$LT_NODE" = app1 ]; then
  mkdir -p /srv/shop
  echo '<!doctype html><title>Shop</title><h1>Example Shop</h1><p>Shop backend app1 OK</p>' > /srv/shop/index.html
  cat > /etc/nginx/conf.d/shop-backend.conf <<'CONF'
# shop backend (behind the load balancer)
server {
    listen 127.0.0.1:8080;
    server_name shop.example.test;
    root /srv/shop;
}
CONF
  cat > /etc/sysconfig/nftables.conf <<'NFT'
# backend firewall: SSH only, plus what the load balancer needs
table inet filter
delete table inet filter
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        iif lo accept
        ct state established,related accept
        tcp dport 22 accept
    }
}
NFT
  systemctl enable --now nftables nginx
  systemctl restart nginx
else
  grep -q 'shop.example.test' /etc/hosts || echo '127.0.0.1 shop.example.test' >> /etc/hosts
  cat > /etc/nginx/conf.d/shop-lb.conf <<'CONF'
# load balancer for the shop
upstream shop_backend {
    server app1:80;
}
server {
    listen 80;
    server_name shop.example.test;
    location / {
        proxy_pass http://shop_backend;
        proxy_set_header Host $host;
        proxy_connect_timeout 3s;
    }
}
CONF
  systemctl enable nginx
  systemctl restart nginx
fi
