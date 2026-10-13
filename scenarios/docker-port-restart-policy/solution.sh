# reference fix (not imported; used by scripts/check_scenarios.py)
docker rm -f status-page >/dev/null
docker run -d --name status-page --restart unless-stopped -p 8080:80 -v /srv/status:/usr/share/nginx/html:ro docker.io/library/nginx:1.27-alpine >/dev/null
sleep 2
