if systemctl is-active --quiet fsupdate 2>/dev/null || systemctl is-enabled --quiet fsupdate 2>/dev/null; then
  fail watcher_gone "the fsupdate service is still active or enabled"
else pass watcher_gone; fi
if grep -rqs '/usr/local/bin/.update\|.sysseed' /etc/cron.d /etc/crontab /var/spool/cron 2>/dev/null; then
  fail cron_gone "a cron job still recreates the file"
else pass cron_gone; fi
[ ! -e /var/lib/.sysseed/.update ] && pass seed_gone || fail seed_gone "the seed copy is still there"
# after the persistence is gone the file must stay gone: delete it and give any watcher a moment
rm -f /usr/local/bin/.update; sleep 3
[ ! -e /usr/local/bin/.update ] && pass file_gone || fail file_gone "the file came back"
crontab -l -u deploy 2>/dev/null | grep -q '/home/deploy/bin/nightly.sh' && pass legit_kept || fail legit_kept "deploy's nightly job is gone"
