sleep 1
curl -s -m 5 http://127.0.0.1:8090/ | grep -q 'notify ok' && pass api_responds || fail api_responds "no answer on port 8090"
check service_active systemctl is-active --quiet notify-api
check service_enabled systemctl is-enabled --quiet notify-api
