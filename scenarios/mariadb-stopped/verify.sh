sql() { mysql -N -B "$@" </dev/null 2>&1; }
rows_ok() { [ "$(sql -uroot -e 'SELECT COUNT(*) FROM shopdb.products' "$@")" = 3 ]; }
check mariadb_running systemctl is-active --quiet mariadb
check mariadb_enabled systemctl is-enabled --quiet mariadb
rows_ok && pass data_intact || fail data_intact "shopdb.products does not have its 3 rows"
[ "$(sql -h127.0.0.1 -ushopapp -pShop-App-Pass-1 -e 'SELECT 1')" = 1 ] && pass app_can_connect || fail app_can_connect "shopapp cannot connect"
