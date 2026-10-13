sleep 3
hb=$(cat /srv/worker/state/heartbeat 2>/dev/null || echo 0)
[ $(( $(date +%s) - hb )) -lt 8 ] && pass heartbeat || fail heartbeat "no fresh heartbeat in /srv/worker/state/heartbeat"
c=$(docker ps -q --filter label=com.docker.compose.project=worker --filter label=com.docker.compose.service=worker | head -1)
if [ -n "$c" ] && docker exec $c env 2>/dev/null | grep -qx 'QUEUE_URL=redis://queue.internal:6379/2'; then pass queue_url_set; else fail queue_url_set "the worker does not get QUEUE_URL=redis://queue.internal:6379/2"; fi
r1=$(docker inspect $c --format '{{.RestartCount}}' 2>/dev/null); sleep 5; r2=$(docker inspect $c --format '{{.RestartCount}}' 2>/dev/null)
if [ -n "$c" ] && [ "$r1" = "$r2" ] && [ "$(docker inspect $c --format '{{.State.Running}}')" = true ]; then pass running_steadily; else fail running_steadily "the worker container is not running steadily"; fi
