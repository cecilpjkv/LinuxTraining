# reference fix (not imported; used by scripts/check_scenarios.py): runs on every server, ns1 first
if [ "$LT_NODE" = ns1 ]; then
  sed -i 's/api.crop.lan/api.corp.lan/' /etc/dnsmasq.d/corp.conf
  echo 'interface=eth0' >> /etc/dnsmasq.d/corp.conf  # the package default (dnsmasq.conf) listens on lo only
  systemctl restart dnsmasq
else
  ns1=$(awk '/ns1.corp.lan/{print $1; exit}' /etc/hosts)
  printf 'search corp.lan\nnameserver %s\n' "$ns1" > /etc/resolv.conf
  sleep 6
fi
