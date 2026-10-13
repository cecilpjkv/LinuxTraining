#!/bin/bash
set -e
mkdir -p /opt/metrics-agent /var/lib/metrics-agent
cat > /opt/metrics-agent/agent <<'SH'
#!/bin/bash
# sends a metrics report every 3 seconds
while true; do date +%s > /var/lib/metrics-agent/last-report; sleep 3; done
SH
cat > /opt/metrics-agent/start <<'SH'
#!/bin/bash
PIDF=/var/lib/metrics-agent/agent.pid
if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
  echo "metrics-agent already running (pid $(cat "$PIDF"))" >&2
  exit 1
fi
nohup /opt/metrics-agent/agent >/dev/null 2>&1 &
echo $! > "$PIDF"
SH
chmod 755 /opt/metrics-agent/agent /opt/metrics-agent/start
cat > /etc/systemd/system/metrics-agent.service <<'UNIT'
[Unit]
Description=Metrics agent

[Service]
Type=forking
PIDFile=/var/lib/metrics-agent/agent.pid
ExecStart=/opt/metrics-agent/start

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable metrics-agent
systemctl is-active --quiet crond || systemctl start crond
# the pid file survived the power cut; after the reboot that number belongs to crond
systemctl show -p MainPID --value crond > /var/lib/metrics-agent/agent.pid
echo 0 > /var/lib/metrics-agent/last-report
systemctl start metrics-agent 2>/dev/null || true
