# test persistence first: restart MariaDB so a runtime-only change would not survive
systemctl restart mariadb 2>/dev/null || true
for i in $(seq 1 30); do mysqladmin ping >/dev/null 2>&1 </dev/null && break; sleep 1; done
ro=$(mysql -N -B </dev/null -e 'SELECT @@global.read_only' 2>/dev/null)
[ "$ro" = 0 ] && pass persistent "read_only=$ro after restart" || fail persistent "read_only=$ro after restart (still read-only in config)"
# the existing data must still be present
seeds=$(mysql -N -B appdb </dev/null -e "SELECT COUNT(*) FROM items WHERE v IN ('seed-1','seed-2')" 2>/dev/null)
[ "$seeds" = 2 ] && pass data_intact || fail data_intact "seed rows present: ${seeds:-0}/2"
# the app user must be able to insert
before=$(mysql -N -B appdb </dev/null -e 'SELECT COUNT(*) FROM items' 2>/dev/null)
mysql -u appuser -pApp-Pass-1 appdb </dev/null -e "INSERT INTO items (v) VALUES ('lt-write-test')" 2>/tmp/.lt-werr
after=$(mysql -N -B appdb </dev/null -e 'SELECT COUNT(*) FROM items' 2>/dev/null)
if [ -n "$after" ] && [ "${before:-0}" -lt "${after:-0}" ]; then pass writes_ok "rows $before -> $after"; else fail writes_ok "insert failed: $(tr -d '\n' </tmp/.lt-werr)"; fi
