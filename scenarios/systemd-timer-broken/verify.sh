check timer_active systemctl is-active --quiet db-backup.timer
check timer_enabled systemctl is-enabled --quiet db-backup.timer
cal=$(systemctl show -p TimersCalendar --value db-backup.timer)
case "$cal" in *"*-*-* 00:00:00"*|*daily*) pass schedule_daily "$cal";; *) fail schedule_daily "schedule: ${cal:-none}";; esac
systemctl start db-backup.service && ls /var/backups/db/ 2>/dev/null | grep -q backup && pass backup_runs || fail backup_runs "the backup job fails"
