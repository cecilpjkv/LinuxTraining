out=$(printf '0 6 * * * /bin/true\n' | runuser -u reports -- crontab - 2>&1) && runuser -u reports -- crontab -l 2>/dev/null | grep -q '/bin/true' && pass reports_can_schedule || fail reports_can_schedule "$(printf '%s' "$out" | head -c 120)"
[ -f /etc/cron.allow ] && grep -qx root /etc/cron.allow && grep -qx backup /etc/cron.allow && pass policy_kept || fail policy_kept "the cron.allow policy was removed or changed"
[ -u /usr/bin/crontab ] && pass crontab_setuid || fail crontab_setuid "crontab lost its setuid bit"
rpm -V cronie 2>/dev/null | grep -q '/usr/bin/crontab' && fail crontab_pristine "crontab differs from its package" || pass crontab_pristine
