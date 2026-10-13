#!/bin/bash
set -e
if [ "$LT_NODE" = logs ]; then
  cat > /etc/rsyslog.d/10-central.conf <<'CONF'
# central log server: messages from other servers go to /var/log/remote/<host>.log
module(load="imudp")
input(type="imudp" port="514" ruleset="remote")
template(name="PerHost" type="string" string="/var/log/remote/%HOSTNAME%.log")
ruleset(name="remote") {
    action(type="omfile" dynaFile="PerHost")
}
CONF
  cat > /etc/sysconfig/nftables.conf <<'NFT'
# log server hardening: only SSH and the log protocol from the web servers
table inet filter
delete table inet filter
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        iif lo accept
        ct state established,related accept
        tcp dport 22 accept
        udp dport 514 accept
    }
}
NFT
  systemctl enable --now nftables
  systemctl restart rsyslog
else
  cat > /etc/rsyslog.d/90-forward.conf <<'CONF'
# send everything to the central log server (TCP, queued while it is unreachable)
*.* action(type="omfwd" target="log01" port="514" protocol="tcp"
           queue.type="LinkedList" queue.size="10000" action.resumeRetryCount="-1" action.resumeInterval="5")
CONF
  systemctl restart rsyslog
  logger -t deploy "web01 deployed release 4.2"
fi
