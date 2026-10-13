#!/bin/bash
set -e
podman load -q -i /opt/lt-images/nginx.tar >/dev/null
mkdir -p /srv/api-docs/public/v2
cat > /srv/api-docs/public/index.html <<'HTML'
<!doctype html><title>API Docs</title><h1>Example API Docs</h1><p>Version 2 reference: <a href="v2/">v2</a></p>
HTML
echo '<!doctype html><title>API v2</title><h1>API v2 reference</h1>' > /srv/api-docs/public/v2/index.html
cat > /srv/api-docs/Dockerfile <<'DF'
# API documentation site
FROM nginx:latest
COPY site/ /usr/share/nginx/html/
EXPOSE 80
DF
printf '# keep the build context small\n.git\n*.md\npublic\n' > /srv/api-docs/.dockerignore
echo '# API docs: build with docker build -t docs:VERSION .' > /srv/api-docs/README.md
