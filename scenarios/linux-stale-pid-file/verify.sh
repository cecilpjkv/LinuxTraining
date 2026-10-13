sleep 4
check agent_running systemctl is-active --quiet metrics-agent
f=/var/lib/metrics-agent/last-report
[ $(( $(date +%s) - $(cat $f 2>/dev/null || echo 0) )) -lt 10 ] && pass agent_reporting || fail agent_reporting "last-report is not being updated"
pid=$(cat /var/lib/metrics-agent/agent.pid 2>/dev/null)
if [ -n "$pid" ] && grep -q metrics-agent/agent /proc/$pid/cmdline 2>/dev/null; then pass pidfile_correct; else fail pidfile_correct "agent.pid does not point at the agent"; fi
systemctl is-active --quiet crond || deduct crond_stopped "crond is not running"
