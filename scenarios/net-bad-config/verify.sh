sleep 1
curl -s -m 5 http://10.50.0.10:8443/ | grep -q 'backend ok' && pass backend_reachable || fail backend_reachable "http://10.50.0.10:8443/ is not reachable"
if ip -br addr show ln-backend 2>/dev/null | grep -q 'UP .*10\.50\.0\.[0-9]*/24'; then pass interface_correct; else fail interface_correct "ln-backend: $(ip -br addr show ln-backend 2>&1 | head -1)"; fi
if systemctl restart backend-net && sleep 1 && curl -s -m 5 http://10.50.0.10:8443/ | grep -q 'backend ok'; then pass persistent; else fail persistent "after restarting backend-net the backend is unreachable"; fi
check service_enabled systemctl is-enabled --quiet backend-net
