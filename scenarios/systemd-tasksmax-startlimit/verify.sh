sleep 3
check service_running systemctl is-active --quiet image-converter
[ -f /run/image-converter.ok ] && [ $(( $(date +%s) - $(stat -c %Y /run/image-converter.ok) )) -lt 6 ] && pass service_healthy || fail service_healthy "the converter is not healthy"
t=$(systemctl show -p TasksMax --value image-converter)
[ "$t" = infinity ] || [ "${t:-0}" -ge 64 ] 2>/dev/null && pass tasks_limit_fits "TasksMax=$t" || fail tasks_limit_fits "TasksMax=$t"
