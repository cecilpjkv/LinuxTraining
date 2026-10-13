sleep 2
cd /srv/portal
docker compose config -q >/tmp/.lt-cc 2>&1 && pass compose_valid || fail compose_valid "$(head -2 /tmp/.lt-cc | tr '\n' ' ')"
if curl -s -m 5 http://127.0.0.1:8090/api/status.json | grep -q '"status": "ok"'; then pass api_through_proxy; else fail api_through_proxy "http://localhost:8090/api/status.json does not answer through the proxy"; fi
running=$(docker ps --filter label=com.docker.compose.project=portal --filter status=running --format '{{.Label "com.docker.compose.service"}}' | sort | tr '\n' ' ')
[ "$running" = "api proxy " ] && pass both_running || fail both_running "running services: ${running:-none}"
for c in $(docker ps -q --filter label=com.docker.compose.project=portal --filter label=com.docker.compose.service=api); do
  [ "$(docker inspect $c --format '{{len .HostConfig.PortBindings}}')" != 0 ] && deduct api_published "the api service is published on the host"
done
