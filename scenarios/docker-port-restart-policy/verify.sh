sleep 1
if curl -s -m 5 http://127.0.0.1:8080/ | grep -q 'all systems operational'; then pass page_loads; else fail page_loads "http://localhost:8080/ does not show the status page"; fi
pol=$(docker inspect status-page --format '{{.HostConfig.RestartPolicy.Name}}' 2>/dev/null)
case "$pol" in always|unless-stopped) pass restart_policy "$pol";; *) fail restart_policy "restart policy: ${pol:-no container}";; esac
if [ "$(docker inspect status-page --format '{{.State.Running}}' 2>/dev/null)" = true ] && \
   docker inspect status-page --format '{{range .Mounts}}{{.Source}} {{end}}' 2>/dev/null | grep -q /srv/status; then
  pass container_ok
else
  fail container_ok "status-page is not running with /srv/status mounted"
fi
