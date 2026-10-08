free=$(df -Pi /srv/spool | awk 'NR==2{print $4}')
[ "$free" -ge 500 ] && pass inodes_free "$free inodes free" || fail inodes_free "only $free inodes free"
if : > /srv/spool/sessions/.lt-test 2>/dev/null; then pass can_create; rm -f /srv/spool/sessions/.lt-test; else fail can_create "cannot create a session file"; fi
n=$(find /srv/spool/sessions -name 'sess_active_*' -mtime -1 | wc -l)
[ "$n" -eq 20 ] && pass active_sessions_kept || fail active_sessions_kept "$n of 20 active sessions left"
if grep -Eq '^[^#]*find +/srv/spool/sessions/? .*-delete' /etc/cron.d/session-cleanup 2>/dev/null || crontab -l 2>/dev/null | grep -Eq '^[^#]*find +/srv/spool/sessions/? .*-delete'; then
  pass cleanup_job_fixed
else
  fail cleanup_job_fixed "the cleanup job still does not clean /srv/spool/sessions"
fi
