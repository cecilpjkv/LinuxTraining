sleep 3
[ -f /run/tls-proxy/ok ] && [ $(( $(date +%s) - $(stat -c %Y /run/tls-proxy/ok) )) -lt 6 ] && pass proxy_reads_key || fail proxy_reads_key "the proxy still cannot read its key"
m=$(stat -c %a /etc/pki/app/proxy.key); g=$(stat -c %G /etc/pki/app/proxy.key)
[ "$m" = 640 ] || [ "$m" = 600 ] || [ "$m" = 440 ] && [ "$g" = certs ] && pass key_protected "$m $g" || fail key_protected "mode $m group $g"
id -nG webproxy | grep -qw certs && pass in_group || fail in_group "webproxy is not in group certs"
