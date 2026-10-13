sleep 3  # opcache / php-fpm settle
H='Host: portal.example.test'
cj=/tmp/.lt-sess; rm -f "$cj"
r1=$(curl -s -m 10 -c "$cj" -b "$cj" -H "$H" http://127.0.0.1/)
r2=$(curl -s -m 10 -c "$cj" -b "$cj" -H "$H" http://127.0.0.1/)
echo "$r1" | grep -q 'COUNT=1' && echo "$r2" | grep -q 'COUNT=2' && pass sessions_persist "r1=$(echo $r1|tr -d '\n') r2=$(echo $r2|tr -d '\n')" || fail sessions_persist "counter did not advance (r1='$(echo $r1|tr -d '\n')' r2='$(echo $r2|tr -d '\n')')"
if printf '%s%s' "$r1" "$r2" | grep -qi 'warning\|session_start\|failed'; then fail no_warning "a PHP session warning is shown"; else pass no_warning; fi
echo "$r1" | grep -q 'COUNT=' && pass site_works || fail site_works "no COUNT on the page"
