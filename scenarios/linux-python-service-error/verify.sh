sleep 1
systemctl is-active --quiet pyapp && pass service_active || fail service_active "pyapp is $(systemctl is-active pyapp 2>/dev/null): $(systemctl show -p ExecMainStatus --value pyapp)"
n=0; d=""
curl -s -m 5 http://127.0.0.1:8080/ | grep -q 'PYAPP-OK' && n=$((n+1)) || d="$d / not PYAPP-OK;"
[ "$(curl -s -m 5 http://127.0.0.1:8080/health | tr -d '[:space:]')" = ok ] && n=$((n+1)) || d="$d /health not ok;"
[ $n = 2 ] && pass app_answers || { [ $n = 1 ] && partial app_answers 0.5 "$d" || fail app_answers "$d"; }
pid=$(pgrep -o -f 'python3? .*app\.py')
if [ -n "$pid" ]; then u=$(ps -o user= -p "$pid" | tr -d ' '); [ "$u" = pyapp ] && pass not_root "pid $pid" || fail not_root "runs as ${u:-?}"; else fail not_root "no python app process"; fi
systemctl restart pyapp 2>/dev/null; sleep 3
systemctl is-active --quiet pyapp && curl -s -m 5 http://127.0.0.1:8080/ | grep -q 'PYAPP-OK' && pass survives || fail survives "not healthy after a restart"
