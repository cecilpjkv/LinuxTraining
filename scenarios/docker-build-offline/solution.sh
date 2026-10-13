# reference fix (not imported; used by scripts/check_scenarios.py)
cd /srv/api-docs
sed -i 's|^FROM nginx:latest|FROM docker.io/library/nginx:1.27-alpine|; s|^COPY site/|COPY public/|' Dockerfile
sed -i '/^public$/d' .dockerignore
docker build -q -t docs:1.0 . >/dev/null
docker run -d --name docs --restart unless-stopped -p 8082:80 docs:1.0 >/dev/null
sleep 2
