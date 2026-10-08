r=$(getent hosts api.payments.internal | awk '{print $1}')
[ "$r" = 10.20.30.40 ] && pass resolves "api.payments.internal = $r" || fail resolves "api.payments.internal -> '${r}'"
check dns_running systemctl is-active --quiet dnsmasq
check dns_enabled systemctl is-enabled --quiet dnsmasq
[ "$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf)" = 127.0.0.1 ] && pass resolver_config || fail resolver_config "the first nameserver is not the local DNS cache"
grep -q 'payments.internal' /etc/hosts && deduct hosts_workaround "names were pinned in /etc/hosts instead of fixing DNS"
