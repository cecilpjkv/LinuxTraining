# reference fix (not imported; used by scripts/check_scenarios.py): runs on every server, logs first
if [ "$LT_NODE" = logs ]; then
  sed -i 's/module(load="imudp")/module(load="imtcp")/; s/input(type="imudp"/input(type="imtcp"/' /etc/rsyslog.d/10-central.conf
  sed -i 's/udp dport 514 accept/tcp dport 514 accept/' /etc/sysconfig/nftables.conf
  systemctl restart nftables rsyslog
else
  sed -i 's/target="log01"/target="logs"/' /etc/rsyslog.d/90-forward.conf
  systemctl restart rsyslog
  sleep 2
fi
