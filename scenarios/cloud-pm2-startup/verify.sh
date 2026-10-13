sleep 1
H='Host: pm2.example.test'
# the app answers through nginx
curl -s -m 5 -H "$H" http://127.0.0.1/ | grep -q 'PM2APP-OK' && pass app_online || fail app_online "pm2.example.test did not answer PM2APP-OK"
# a pm2 boot service exists and is enabled (pm2 startup creates pm2-<user>.service)
svc=$(systemctl list-unit-files --no-legend 'pm2-*.service' 2>/dev/null | awk '{print $1}' | head -1)
if [ -n "$svc" ] && systemctl is-enabled --quiet "$svc"; then pass boot_service "$svc"; else fail boot_service "no enabled pm2-*.service (run pm2 startup)"; fi
# the saved process list (resurrected on boot) must exist and include the app
dump=$(ls /home/appops/.pm2/dump.pm2 2>/dev/null)
if [ -n "$dump" ] && grep -q 'pm2app' "$dump" 2>/dev/null; then pass saved_list "$dump"; else fail saved_list "no saved dump with pm2app (run pm2 save)"; fi
# the node process runs as appops, not root
pid=$(pgrep -u appops -f 'server\.js' | head -1)
if [ -n "$pid" ]; then u=$(ps -o user= -p "$pid" | tr -d ' '); [ "$u" = appops ] && pass not_root "pid $pid" || fail not_root "runs as ${u:-?}"; else fail not_root "no app process for appops"; fi
