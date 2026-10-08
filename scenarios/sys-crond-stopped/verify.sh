check crond_running systemctl is-active --quiet crond
check crond_enabled systemctl is-enabled --quiet crond
grep -q 'root date' /etc/cron.d/heartbeat && pass jobs_kept || fail jobs_kept "the heartbeat job was changed or removed"
