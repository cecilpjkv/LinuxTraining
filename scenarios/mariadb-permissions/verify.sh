sql() { mysql -N -B "$@" </dev/null 2>&1; }
rows_ok() { [ "$(sql -uroot -e 'SELECT COUNT(*) FROM shopdb.products' "$@")" = 3 ]; }
out=$(/usr/local/bin/sales-report 2>&1)
printf '%s' "$out" | grep -q 'Product C' && pass report_works || fail report_works "$(printf '%s' "$out" | head -c 160)"
g=$(sql -uroot -e "SHOW GRANTS FOR 'reporting'@'localhost'")
if printf '%s' "$g" | grep -Eqi 'ALL PRIVILEGES|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|SUPER|GRANT OPTION'; then fail least_privilege "reporting can do more than read: $g"; else pass least_privilege; fi
