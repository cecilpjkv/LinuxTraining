# reference fix (not imported; used by scripts/check_scenarios.py)
cd /srv/worker
sed -i 's/^QUEUE_ULR=/QUEUE_URL=/' worker.env
docker compose up -d >/dev/null 2>&1
sleep 3
