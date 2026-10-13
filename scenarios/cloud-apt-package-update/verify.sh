sleep 1
NEW=1.22.1-9+deb12u10
v1=$(dpkg-query -W -f='${Version}' nginx 2>/dev/null); v2=$(dpkg-query -W -f='${Version}' nginx-common 2>/dev/null)
[ "$v1" = $NEW ] && [ "$v2" = $NEW ] && pass nginx_updated "$v1" || fail nginx_updated "nginx $v1, nginx-common $v2"
# the master process must have been started from the new binary (a package upgrade restarts it; a stale one shows "(deleted)")
pid=$(systemctl show -p MainPID --value nginx 2>/dev/null)
if [ -n "$pid" ] && [ "$pid" != 0 ]; then
  started=$(stat -c %Y /proc/$pid 2>/dev/null); built=$(stat -c %Z /usr/sbin/nginx)  # change time: when it was installed
  if ls -l /proc/$pid/exe 2>/dev/null | grep -q deleted || [ "${started:-0}" -lt "$built" ]; then fail running_new "the running master predates the installed binary"
  elif [ "$v1" = $NEW ]; then pass running_new "pid $pid"; else fail running_new "the package is not updated"; fi
else fail running_new "nginx is not running"; fi
systemctl is-active --quiet nginx && systemctl is-enabled --quiet nginx && pass service_ok || fail service_ok "$(systemctl is-active nginx) / $(systemctl is-enabled nginx 2>&1)"
curl -s -m 5 -H 'Host: www.example.test' http://127.0.0.1/ | grep -q 'Site OK' && pass site_works || fail site_works "HTTP $(http_code -H 'Host: www.example.test' http://127.0.0.1/)"
[ "$(dpkg-query -W -f='${Version}' openssl)" = "$(cat /var/lib/.lt-openssl 2>/dev/null)" ] || deduct other_upgraded "openssl $(dpkg-query -W -f='${Version}' openssl)"
