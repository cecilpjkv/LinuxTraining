#!/bin/bash
set -e
podman load -q -i /opt/lt-images/nginx.tar >/dev/null
podman load -q -i /opt/lt-images/busybox.tar >/dev/null
mkdir -p /srv/portal/proxy /srv/portal/api/www
cat > /srv/portal/proxy/default.conf <<'CONF'
server {
    listen 80;
    location / {
        return 200 "customer portal\n";
    }
    location /api/ {
        proxy_pass http://api:8080/;
    }
}
CONF
cat > /srv/portal/api/www/status.json <<'JSON'
{"service": "portal-api", "status": "ok"}
JSON
cat > /srv/portal/compose.yaml <<'YAML'
name: portal
services:
  proxy:
    image: docker.io/library/nginx:1.27-alpine
    restart: unless-stopped
    ports:
      - "8090:80"
    volumes:
      - ./proxy/default.conf:/etc/nginx/conf.d/default.conf:ro
    networks: [frontend]
    depends_on: [api]
  api:
    image: docker.io/library/busybox:1.36
    restart: unless-stopped
    command: ["httpd", "-f", "-v", "-p", "80", "-h", "/www"]
    volumes:
      - ./api/www:/www:ro
    networks: [backend]

networks:
  frontend:
  backend:
YAML
cd /srv/portal && docker compose up -d >/dev/null 2>&1 || true
