sleep 1
if command -v node >/dev/null && command -v npm >/dev/null; then pass node_installed "node $(node -v), npm $(npm -v 2>/dev/null)"; else fail node_installed "node: $(command -v node || echo missing), npm: $(command -v npm || echo missing)"; fi
n=0; d=""
curl -s -m 5 http://127.0.0.1:3000/ | grep -q 'Hello from Node' && n=$((n+1)) || d="$d / does not say Hello from Node;"
[ "$(curl -s -m 5 http://127.0.0.1:3000/health | tr -d '[:space:]')" = ok ] && n=$((n+1)) || d="$d /health does not answer ok;"
[ $n = 2 ] && pass app_responds || partial app_responds "$(echo "scale=2; $n/2" | bc)" "$d"
curl -s -m 5 -H 'Host: app.example.test' http://127.0.0.1/ | grep -q 'Hello from Node' && pass site_works || fail site_works "app.example.test: HTTP $(http_code -H 'Host: app.example.test' http://127.0.0.1/)"
# the node process behind port 3000 (ss -p cannot see other users' sockets in a lab: no CAP_SYS_PTRACE)
listening() { ss -ltnH 'sport = :3000' | grep -q LISTEN; }
nodepid() { pgrep -o -x node || pgrep -o -f 'node .*\.js'; }
pid=$(listening && nodepid)
if [ -z "$pid" ]; then
  for c in not_root service_enabled auto_restart logs; do fail $c "nothing listens on port 3000"; done
else
  u=$(ps -o user= -p "$pid" | tr -d ' ')
  [ "$u" = nodeapp ] && pass not_root || fail not_root "runs as ${u:-?}"
  unit=$(systemctl status "$pid" --no-pager 2>/dev/null | awk 'NR==1{print $2}')
  case "$unit" in
    *.service) systemctl is-enabled --quiet "$unit" && pass service_enabled "$unit" || fail service_enabled "$unit is not enabled";;
    *) fail service_enabled "the process is not run by a systemd service";;
  esac
  tag=lt$RANDOM; curl -s -o /dev/null -m 5 "http://127.0.0.1:3000/?probe=$tag"; sleep 2
  case "$unit" in *.service) journalctl -u "$unit" --since '-2min' --no-pager 2>/dev/null | grep -q "$tag\|probe" && pass logs "$unit" || fail logs "no line for the request in the journal of $unit";; *) fail logs "not a service";; esac
  kill -9 "$pid"
  new=""
  for i in $(seq 1 20); do sleep 1; new=$(listening && nodepid); [ -n "$new" ] && [ "$new" != "$pid" ] && break; done
  [ -n "$new" ] && [ "$new" != "$pid" ] && curl -s -m 5 http://127.0.0.1:3000/ | grep -q 'Hello from Node' && pass auto_restart "back as pid $new" || fail auto_restart "not back 20 s after kill -9"
fi
