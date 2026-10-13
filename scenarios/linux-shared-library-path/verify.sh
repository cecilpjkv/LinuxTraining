sleep 6
if out=$(echo '{"a":1}' | env -i /opt/vendor/bin/report-tool -c . 2>&1); then pass tool_runs; else fail tool_runs "$out"; fi
f=/var/lib/report/latest.json
if systemctl is-active --quiet report-export && [ -f $f ] && [ $(( $(date +%s) - $(stat -c %Y $f) )) -lt 15 ] && grep -q '"status":"ok"' $f; then
  pass export_works
else
  fail export_works "latest.json is not being refreshed"
fi
bad=""
for d in $(cat /etc/ld.so.conf.d/*.conf 2>/dev/null | grep -v '^\s*#' | grep '^/'); do [ -d "$d" ] || bad="$bad $d"; done
[ -z "$bad" ] && pass linker_config_clean || fail linker_config_clean "ld.so.conf.d lists missing directories:$bad"
