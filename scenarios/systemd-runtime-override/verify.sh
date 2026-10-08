sleep 2
curl -s -m 5 http://127.0.0.1:8081/ | grep -q 'inventory ok' && pass api_on_8081 || fail api_on_8081 "nothing answers on 8081"
d=$(systemctl show -p DropInPaths --value inventory-api)
case "$d" in *50-debug*|*10-test*) fail no_stray_overrides "still active: $d";; *) pass no_stray_overrides;; esac
check service_active systemctl is-active --quiet inventory-api
