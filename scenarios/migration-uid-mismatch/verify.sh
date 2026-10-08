sleep 3
check service_running systemctl is-active --quiet archive
[ -f /run/archive/ok ] && [ $(( $(date +%s) - $(stat -c %Y /run/archive/ok) )) -lt 6 ] && pass service_healthy || fail service_healthy "the archive service cannot use its files"
bad=$(find /srv/archive -nouser -o -nogroup | head -3 | tr '\n' ' ')
[ -z "$bad" ] && [ "$(stat -c %U /srv/archive/data)" = archive ] && pass owners_fixed || fail owners_fixed "orphaned owners: $bad"
check service_enabled systemctl is-enabled --quiet archive
if grep -Eq '^[^#]*([^ ]+ +){5}(root|archive) +/usr/local/sbin/archive-export' /etc/cron.d/archive-export && runuser -u archive -- /usr/local/sbin/archive-export 2>/dev/null; then pass export_works; else fail export_works "the export job is not valid or fails"; fi
