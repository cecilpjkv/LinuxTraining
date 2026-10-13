# reference fix (not imported; used by scripts/check_scenarios.py): runs on every server, backup first
if [ "$LT_NODE" = backup ]; then
  web=$(getent hosts web | awk '{print $1; exit}')
  sed -i "s/from=\"10.99.0.5\"/from=\"$web\"/" /home/backup/.ssh/authorized_keys
  chown backup:backup /srv/backups/web
else
  ssh-keygen -R backup -f /root/.ssh/known_hosts
  ssh-keyscan -t ed25519 backup >> /root/.ssh/known_hosts 2>/dev/null
  /usr/local/sbin/site-backup </dev/null
fi
