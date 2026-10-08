sql() { mysql -N -B "$@" </dev/null 2>&1; }
rows_ok() { [ "$(sql -uroot -e 'SELECT COUNT(*) FROM shopdb.products' "$@")" = 3 ]; }
check mariadb_running systemctl is-active --quiet mariadb
[ "$(sql -uroot -e 'SELECT @@max_connections')" = 500 ] && pass tuning_applied || fail tuning_applied "max_connections is not 500"
rows_ok && pass data_intact || fail data_intact "shopdb is not intact"
