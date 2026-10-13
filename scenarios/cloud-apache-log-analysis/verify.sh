LOG=/var/log/httpd/vhosts/shop.example.test-access_log
ans() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" /root/answers.txt 2>/dev/null | tail -1 | tr -d ' \r"'"'"; }
a=$(ans access_log)
if [ -n "$a" ] && [ "$(readlink -f "$a" 2>/dev/null)" = "$LOG" ]; then pass log_found "$a"; else fail log_found "answer: ${a:-empty}"; fi
right=0 wrong=""
for c in 200 301 403 404 500; do
  want=$(awk -v c=$c '$9 == c' "$LOG" | wc -l); got=$(ans count_$c)
  if [ "$got" = "$want" ]; then right=$((right+1)); else wrong="$wrong $c:${got:-empty}"; fi
done
[ $right = 5 ] && pass status_counts "all 5 right" || partial status_counts "$(echo "scale=2; $right/5" | bc)" "$right of 5 right; wrong:$wrong"
want=$(awk '{print $1}' "$LOG" | sort | uniq -c | sort -rn | awk 'NR==1{print $2}')
got=$(ans top_ip)
[ -n "$got" ] && [ "$got" = "$want" ] && pass top_ip "$got" || fail top_ip "answer: ${got:-empty}"
