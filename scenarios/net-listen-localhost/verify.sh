sleep 1
ip=$(hostname -I | awk '{print $1}')
curl -s -m 5 "http://$ip:9100/metrics" | grep -q node_up && pass reachable_from_network "http://$ip:9100" || fail reachable_from_network "http://$ip:9100 does not answer"
check service_running systemctl is-active --quiet metrics-api
ss -ltn | grep -Eq '[:.]9100 ' && pass port_unchanged || fail port_unchanged "nothing listens on 9100"
