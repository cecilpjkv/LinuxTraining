sql() { mysql -N -B "$@" </dev/null 2>&1; }
rows_ok() { [ "$(sql -uroot -e 'SELECT COUNT(*) FROM shopdb.products' "$@")" = 3 ]; }
check mariadb_running systemctl is-active --quiet mariadb
[ "$(sql -h127.0.0.1 -P3306 -ushopapp -pShop-App-Pass-1 -e 'SELECT 1')" = 1 ] && pass tcp_3306 || fail tcp_3306 "no connection to 127.0.0.1:3306"
l=$(ss -ltn | awk '$4 ~ /:3306$/ {print $4}' | tr '\n' ' ')
case " $l " in *" 0.0.0.0:3306 "*|*"[::]:3306"*|*"*:3306"*) fail local_only "listening on all addresses: $l";; "  ") fail local_only "not listening";; *) pass local_only "$l";; esac
rows_ok && pass data_intact || fail data_intact "shopdb is not intact"
