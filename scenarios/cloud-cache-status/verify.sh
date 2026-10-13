ans() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" /root/answers.txt 2>/dev/null | tail -1 | tr -d '\r'; }
st() { local v; v=$(ans "$2" | tr -d ' "' | tr a-z A-Z); [ "$v" = "$3" ] && pass "$1" "$v" || fail "$1" "answer: ${v:-empty}"; }
why() { local v; v=$(ans "$2"); if [ -n "$v" ] && printf '%s' "$v" | grep -Eqi "$3"; then pass "$1" "$v"; else fail "$1" "answer: ${v:-empty}"; fi; }
st home_cached home_repeat_status HIT
st account_status account_status BYPASS
why account_reason account_reason 'bypass|no.?cache|location|config|personal|account|never|excluded|disabled|skip'
st session_status logged_in_status BYPASS
why session_reason logged_in_reason 'cookie|session|logged|login'
st stock_status stock_status MISS
why stock_reason stock_reason 'no-store|private|cache-control|header|backend|application|upstream|origin'
[ "$(md5sum /etc/nginx/conf.d/shop.conf 2>/dev/null | cut -d' ' -f1)" = "$(cat /var/lib/.lt-shop-conf 2>/dev/null)" ] \
  && pass config_unchanged || fail config_unchanged "/etc/nginx/conf.d/shop.conf was changed"
