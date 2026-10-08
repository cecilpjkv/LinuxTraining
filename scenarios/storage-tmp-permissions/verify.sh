sleep 3
m=$(stat -c %a /tmp)
[ "$m" = 1777 ] && pass tmp_mode || fail tmp_mode "/tmp has mode $m"
if [ -f /run/report-builder/ok ] && [ $(( $(date +%s) - $(stat -c %Y /run/report-builder/ok) )) -lt 8 ]; then pass app_works; else fail app_works "the report builder still fails"; fi
runuser -u reports -- mktemp >/dev/null 2>&1 && pass any_user_mktemp || fail any_user_mktemp "a normal user cannot create temporary files"
