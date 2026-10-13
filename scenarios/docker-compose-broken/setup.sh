#!/bin/bash
set -e
podman load -q -i /opt/lt-images/nginx.tar >/dev/null
mkdir -p /srv/shop/html
echo '<!doctype html><title>Shop</title><h1>Shop front</h1><p>Welcome to the Example Shop</p>' > /srv/shop/html/index.html
cat > /srv/shop/compose.yaml <<'YAML'
name: shop
services:
  web:
    image: docker.io/library/nginx:1.27-alpine
    restart: unless-stopped
    ports:
    - "${SHOP_PORT}:80"
    volumes:
      - ./htm:/usr/share/nginx/html:ro
   healthcheck:
      test: ["CMD", "wget", "-q", "-O", "/dev/null", "http://127.0.0.1/"]
      interval: 10s
YAML
printf '# shop front settings\nSHOP_PORT=8081\n' > /srv/shop/shop.env
