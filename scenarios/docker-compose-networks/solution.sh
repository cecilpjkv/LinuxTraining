# reference fix (not imported; used by scripts/check_scenarios.py)
cd /srv/portal
sed -i 's/    networks: \[frontend\]/    networks: [frontend, backend]/; s/"-p", "80"/"-p", "8080"/' compose.yaml
docker compose up -d >/dev/null 2>&1
sleep 4
