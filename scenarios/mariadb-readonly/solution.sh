# reference fix: remove the read-only setting from the config and turn it off now
rm -f /etc/my.cnf.d/zz-readonly.cnf
mysql </dev/null -e "SET GLOBAL read_only=OFF" 2>/dev/null || true
