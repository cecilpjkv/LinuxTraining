#!/bin/bash
set -e
rm -f /etc/ssh/sshd_config.d/*permitrootlogin*.conf
if [ "$LT_NODE" = backup ]; then
  id backup >/dev/null 2>&1 || useradd -m -s /bin/bash backup
  install -d -m 755 /srv/backups
  install -d -m 755 -o root -g root /srv/backups/web
  # the web server's backup key (made here, handed to web below: the private key does not stay on this server)
  k=$(mktemp -d)
  ssh-keygen -q -t ed25519 -N '' -C 'root@web site-backup' -f $k/key
  install -d -m 700 -o backup -g backup /home/backup/.ssh
  # restricted to the web server's address (its old one: the network was renumbered with the move)
  echo "from=\"10.99.0.5\",no-pty,no-agent-forwarding,no-X11-forwarding $(cat $k/key.pub)" > /home/backup/.ssh/authorized_keys
  chown backup:backup /home/backup/.ssh/authorized_keys
  chmod 600 /home/backup/.ssh/authorized_keys
  echo "@@LT SHARE BACKUP_KEY $(base64 -w0 < $k/key)"
  rm -rf $k
  systemctl enable sshd && systemctl restart sshd
else
  mkdir -p /var/www/site/img
  echo '<!doctype html><title>Example Corp</title><h1>Example Corp</h1>' > /var/www/site/index.html
  echo 'User-agent: *' > /var/www/site/robots.txt
  head -c 20000 /dev/urandom > /var/www/site/img/logo.png
  install -d -m 700 /root/.ssh
  printf '%s' "$LT_SHARE_BACKUP_KEY" | base64 -d > /root/.ssh/backup_key
  chmod 600 /root/.ssh/backup_key
  # the backup server's host key from before the reinstall
  k=$(mktemp -d)
  ssh-keygen -q -t ed25519 -N '' -f $k/old
  echo "backup $(cut -d' ' -f1,2 $k/old.pub)" > /root/.ssh/known_hosts
  rm -rf $k
  cat > /usr/local/sbin/site-backup <<'SH'
#!/bin/bash
# nightly site backup to the backup server (cron: /etc/cron.d/site-backup)
set -o pipefail
rsync -a --delete -e "ssh -i /root/.ssh/backup_key -o BatchMode=yes -o ConnectTimeout=10" \
  /var/www/site/ backup@backup:/srv/backups/web/ 2>&1 | logger -s -t site-backup
SH
  chmod 755 /usr/local/sbin/site-backup
  echo '30 2 * * * root /usr/local/sbin/site-backup' > /etc/cron.d/site-backup
  /usr/local/sbin/site-backup </dev/null || true
fi
