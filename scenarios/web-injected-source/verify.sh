sleep 3  # opcache re-reads changed PHP every 2 s
H='Host: www.portal.example.test'
# no original PHP file still carries the loader signature
hits=$(grep -rl 'include_once(__DIR__ . "/' /srv/www/portal --include='*.php' 2>/dev/null | grep -v '/\.query\.php$' | tr '\n' ' ')
[ -z "$hits" ] && ! grep -rqs 'error_reporting(0)' /srv/www/portal/index.php /srv/www/portal/inc/header.php /srv/www/portal/inc/footer.php /srv/www/portal/inc/lib.php && pass files_clean || fail files_clean "still injected: ${hits:-see error_reporting}"
# the payload is gone
[ ! -e /srv/www/portal/inc/.query.php ] && pass payload_gone || fail payload_gone "the payload file is still there"
# behaviour: the eval backdoor must not run (base64 of: echo "PWN-".(3*3);)
q=$(printf 'echo "PWN-".(3*3);' | base64 -w0)
if curl -s -m 10 -H "$H" "http://127.0.0.1/?q=$q" | grep -q 'PWN-9'; then fail no_exec "the injected backdoor still executes"; else pass no_exec; fi
# the real page works
code=$(curl -s -o /tmp/.lt-b -m 15 -w '%{http_code}' -H "$H" http://127.0.0.1/)
if [ "$code" = 200 ] && grep -q 'PORTAL-HOME-OK' /tmp/.lt-b; then pass site_works "HTTP $code"; else fail site_works "HTTP $code, marker missing"; fi
