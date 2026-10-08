curl -s -m 5 http://127.0.0.1:8081/health | grep -q '^OK' && pass api_responds || fail api_responds "no answer on 127.0.0.1:8081/health"
systemctl is-active --quiet inventory-api && pass service_active || fail service_active "inventory-api is not active"
systemctl is-enabled --quiet inventory-api && pass service_enabled || fail service_enabled "not enabled at boot"
exe=$(systemctl show -p ExecStart --value inventory-api | sed -n 's/.*path=\([^ ;]*\).*/\1/p')
[ -n "$exe" ] && [ -x "$exe" ] && pass unit_valid "$exe" || fail unit_valid "ExecStart points to '${exe}'"
