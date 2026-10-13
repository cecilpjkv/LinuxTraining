# reference fix (not imported; used by scripts/check_scenarios.py)
cd /srv/shop
sed -i 's/^   healthcheck:/    healthcheck:/; s|- ./htm:|- ./html:|' compose.yaml
mv shop.env .env
docker compose up -d >/dev/null 2>&1
sleep 3
