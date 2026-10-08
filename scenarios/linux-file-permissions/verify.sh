sleep 4
systemctl is-active --quiet reportd && pass service_running || fail service_running "reportd is not running"
f=/var/lib/reportd/last-run.txt
if [ -f "$f" ] && [ $(( $(date +%s) - $(stat -c %Y "$f") )) -lt 15 ]; then pass output_written; else fail output_written "no fresh report in $f"; fi
mode=$(stat -c %a /opt/reportd/config.ini)
case "$mode" in *[1-7]) fail config_protected "config.ini is readable by everybody (mode $mode)";; *) pass config_protected "mode $mode";; esac
