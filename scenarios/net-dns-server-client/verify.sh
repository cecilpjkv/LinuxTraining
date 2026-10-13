if [ "$LT_NODE" = app ]; then
  sleep 6
  ip=$(getent hosts intranet.corp.lan | awk '{print $1; exit}')
  [ "$ip" = 10.20.30.40 ] && pass intranet_resolves || fail intranet_resolves "intranet.corp.lan -> ${ip:-nothing}"
  read -r ts st addr _ < /var/lib/inventory/status 2>/dev/null
  if [ "$st" = ok ] && [ "$addr" = 10.20.30.41 ] && [ $(( $(date +%s) - ${ts:-0} )) -lt 15 ]; then pass api_resolves; else fail api_resolves "inventory-sync: $(cat /var/lib/inventory/status 2>/dev/null)"; fi
  if grep -v '^\s*#' /etc/hosts | grep -Eiq '\b(intranet|api|git)\.(corp|crop)\.lan\b'; then deduct hosts_workaround "corp.lan names were added to /etc/hosts"; fi
else
  dnsmasq --test >/tmp/.lt-dt 2>&1 && pass config_valid || fail config_valid "$(cat /tmp/.lt-dt)"
  lan=$(hostname -I | awk '{print $1}')
  if systemctl is-active --quiet dnsmasq && [ "$(dig +short +time=2 +tries=1 @"$lan" git.corp.lan)" = 10.20.30.42 ]; then pass server_reachable; else fail server_reachable "dnsmasq does not answer on $lan"; fi
fi
