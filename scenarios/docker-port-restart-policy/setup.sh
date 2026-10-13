#!/bin/bash
set -e
podman load -q -i /opt/lt-images/nginx.tar >/dev/null
mkdir -p /srv/status
cat > /srv/status/index.html <<'HTML'
<!doctype html><title>Status</title><h1>Example Corp status</h1><p>Status: all systems operational</p>
HTML
docker run -d --name status-page -p 8080:8080 -v /srv/status:/usr/share/nginx/html:ro docker.io/library/nginx:1.27-alpine >/dev/null
docker stop status-page >/dev/null
