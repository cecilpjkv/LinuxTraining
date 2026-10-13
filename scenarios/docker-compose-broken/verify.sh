sleep 1
cd /srv/shop
docker compose config -q >/tmp/.lt-cc 2>&1 && pass compose_valid || fail compose_valid "$(head -2 /tmp/.lt-cc | tr '\n' ' ')"
if curl -s -m 5 http://127.0.0.1:8081/ | grep -q 'Welcome to the Example Shop'; then pass shop_serves; else fail shop_serves "http://localhost:8081/ does not show the shop page"; fi
if [ -n "$(docker ps -q --filter label=com.docker.compose.project=shop --filter status=running)" ]; then pass started_by_compose; else fail started_by_compose "no running container of the compose project shop"; fi
