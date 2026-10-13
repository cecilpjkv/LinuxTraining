# reference fix (not imported; used by scripts/check_scenarios.py)
cd /srv/shop
sed -i -e 's|php:8.1-fpm-alpine|php:8.3-fpm-alpine|' -e 's|mariadb:10.11.18|mariadb:10.11.14|' compose.yaml
docker compose up -d >/dev/null 2>&1 </dev/null
docker compose restart web >/dev/null 2>&1 </dev/null   # nginx resolved the old php container's address at start
for i in $(seq 1 60); do docker compose exec -T db mariadb-admin ping -h 127.0.0.1 >/dev/null 2>&1 </dev/null && break; sleep 1; done
sleep 2
