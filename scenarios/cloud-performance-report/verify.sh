ans() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" /root/answers.txt 2>/dev/null | tail -1 | tr -d '\r'; }
has() { local v; v=$(ans "$2"); if [ -n "$v" ] && printf '%s' "$v" | grep -Eqi "$3"; then pass "$1" "$v"; else fail "$1" "answer: ${v:-empty}"; fi; }
has cpu_process high_cpu_process 'feed-export'
has memory_process high_memory_process 'thumbnail'
v=$(ans largest_app_dir | tr -d ' "'"'"); v=${v%/}
case "$v" in */var|var|*/var/cache|var/cache|*/var/cache/pages|var/cache/pages) pass largest_dir "$v";; *) fail largest_dir "answer: ${v:-empty}";; esac
want=$(awk '{print $1}' /var/log/nginx/shop.access.log | sort | uniq -c | sort -rn | awk 'NR==1{print $2}')
v=$(ans top_ip | tr -d ' ')
[ -n "$v" ] && [ "$v" = "$want" ] && pass top_ip "$v" || fail top_ip "answer: ${v:-empty}"
has slow_query slow_query 'customer-lifetime-value|lifetime'
# the slow log: on now, with a 2 s threshold, and in the configuration for the next start
q() { mysql -N -B </dev/null -e "SELECT @@GLOBAL.$1" 2>/dev/null; }
on=$(q slow_query_log); lt=$(q long_query_time)
conf=$(my_print_defaults --mysqld 2>/dev/null)
c_on=$(printf '%s\n' "$conf" | grep -E '^--(slow[_-]query[_-]log|log[_-]slow[_-]queries)(=(1|ON|on))?$' | tail -1)
c_lt=$(printf '%s\n' "$conf" | sed -nE 's/^--long[_-]query[_-]time=//p' | tail -1)
n=0; d=""
[ "$on" = 1 ] && n=$((n+1)) || d="$d off now;"
python3 -c "import sys; sys.exit(0 if abs(float('${lt:-0}') - 2) < 0.001 else 1)" 2>/dev/null && n=$((n+1)) || d="$d threshold ${lt}s;"
[ -n "$c_on" ] && python3 -c "import sys; sys.exit(0 if abs(float('${c_lt:-10}') - 2) < 0.001 else 1)" 2>/dev/null && n=$((n+1)) || d="$d not in the configuration;"
[ $n = 3 ] && pass slow_log_on "on, 2 s, configured" || partial slow_log_on "$(echo "scale=2; $n/3" | bc)" "$d"
for s in feed-export thumbnail-cache shop-reports mariadb nginx php-fpm; do
  systemctl is-active --quiet $s || { deduct services_stopped "$s is not running"; break; }
done
