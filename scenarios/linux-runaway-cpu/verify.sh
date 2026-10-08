# nothing burns the CPU (sampled over 2 seconds), the generator is stopped and will not start at boot
busy=$(top -b -n 2 -d 2 | awk '/^top -/{n++} n==2 && $1 ~ /^[0-9]+$/ && $9+0 > 30 && $12 != "top" {print $12}' | head -1)
[ -z "$busy" ] && pass cpu_normal || fail cpu_normal "still busy: $busy"
if systemctl is-active --quiet report-generator || pgrep -f /opt/reports/bin/report-generator >/dev/null; then
  fail generator_stopped "report-generator is running"
else
  pass generator_stopped
fi
systemctl is-enabled --quiet report-generator 2>/dev/null && fail generator_disabled "still enabled at boot" || pass generator_disabled
if systemctl is-active --quiet metrics-agent && curl -s -m 5 http://127.0.0.1:9100/ | grep -q 'metrics ok'; then
  pass metrics_running
else
  fail metrics_running "metrics agent not answering"
fi
