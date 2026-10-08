sleep 2
check agent_running systemctl is-active --quiet acme-agent
sha256sum -c --quiet /root/.lt-acme.sha256 >/dev/null 2>&1 && pass config_restored || fail config_restored "agent.conf is missing or differs from the backup"
m=$(stat -c %a /etc/acme/agent.conf 2>/dev/null)
case "$m" in *0) [ "$(stat -c %G /etc/acme/agent.conf)" = acme ] && pass config_protected "mode $m" || fail config_protected "group is not acme";; "") fail config_protected "missing";; *) fail config_protected "readable by everybody (mode $m)";; esac
