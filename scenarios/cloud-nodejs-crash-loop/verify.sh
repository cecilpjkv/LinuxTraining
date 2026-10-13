sleep 1
H='Host: api.shop.example.test'
systemctl is-active --quiet shop-api && pass service_active "$(systemctl show -p ActiveState --value shop-api)" || fail service_active "shop-api is $(systemctl is-active shop-api 2>/dev/null)"
listening() { ss -ltnH 'sport = :3000' | grep -q LISTEN; }
listening && pass port_3000 || fail port_3000 "nothing listens on 3000"
n=0; d=""
curl -s -m 5 -H "$H" http://127.0.0.1/ | grep -q 'SHOP-API-OK' && n=$((n+1)) || d="$d / not SHOP-API-OK;"
[ "$(curl -s -m 5 -H "$H" http://127.0.0.1/health | tr -d '[:space:]')" = ok ] && n=$((n+1)) || d="$d /health not ok;"
[ $n = 2 ] && pass site_works || { [ $n = 1 ] && partial site_works 0.5 "$d" || fail site_works "$d"; }
# the process behind 3000 must not be root
pid=$(pgrep -o -x node || pgrep -o -f 'node .*server\.js')
if [ -n "$pid" ]; then u=$(ps -o user= -p "$pid" | tr -d ' '); [ "$u" = nodeapp ] && pass not_root "pid $pid" || fail not_root "runs as ${u:-?}"; else fail not_root "no node process"; fi
# survives a restart
systemctl restart shop-api 2>/dev/null; sleep 3
systemctl is-active --quiet shop-api && curl -s -m 5 -H "$H" http://127.0.0.1/ | grep -q 'SHOP-API-OK' && pass survives || fail survives "not healthy after a restart"
