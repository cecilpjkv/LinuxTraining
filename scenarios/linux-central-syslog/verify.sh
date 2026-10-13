if [ "$LT_NODE" = web01 ]; then
  rsyslogd -N1 >/tmp/.lt-rs 2>&1 && pass config_valid || fail config_valid "web01: $(grep -i error /tmp/.lt-rs | head -1)"
  # a probe message; the log server is checked after this
  logger -t lt-verify "central logging probe $(date +%s)"
  sleep 8
else
  rsyslogd -N1 >/tmp/.lt-rs 2>&1 && pass config_valid || fail config_valid "logs: $(grep -i error /tmp/.lt-rs | head -1)"
  ss -ltn | grep -qE '[:*]514\s' && pass tcp_listening || fail tcp_listening "nothing listens on TCP 514"
  now=$(date +%s); got=""
  for ts in $(grep -ho 'central logging probe [0-9]*' /var/log/remote/web01.log 2>/dev/null | awk '{print $4}'); do
    [ $((now - ts)) -lt 120 ] && got=1
  done
  [ -n "$got" ] && pass logs_arrive || fail logs_arrive "no fresh message from web01 in /var/log/remote/web01.log"
  if nft list chain inet filter input 2>/dev/null | grep -q 'policy drop'; then pass firewall_kept; else fail firewall_kept "the input firewall (policy drop) is gone"; fi
fi
