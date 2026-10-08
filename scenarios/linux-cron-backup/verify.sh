check script_executable test -x /usr/local/bin/app-backup.sh
if grep -Eq '^[^#]*([^ ]+ +){5}root +(/bin/(ba)?sh +)?/usr/local/bin/app-backup\.sh' /etc/cron.d/app-backup 2>/dev/null \
   || crontab -l -u root 2>/dev/null | grep -Eq '^[^#]*([^ ]+ +){5}(/bin/(ba)?sh +)?/usr/local/bin/app-backup\.sh'; then
  pass schedule_valid
else
  fail schedule_valid "no valid cron entry runs /usr/local/bin/app-backup.sh"
fi
before=$(ls /var/backups/app | wc -l)
sleep 1
if /usr/local/bin/app-backup.sh 2>/dev/null && [ "$(ls /var/backups/app | wc -l)" -gt "$before" ]; then pass backup_runs; else fail backup_runs "running the job does not create a backup"; fi
systemctl is-active --quiet crond && pass crond_running || fail crond_running "crond is not running"
