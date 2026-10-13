export GIT_SSH_COMMAND="ssh -i /etc/lt-ssh-test/dev -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
w=$(mktemp -d); tok="lt-$RANDOM$RANDOM"
if git clone -q deploy@127.0.0.1:/srv/git/app.git $w/app </dev/null 2>/dev/null && cd $w/app; then
  git config user.name verify; git config user.email verify@example.test
  echo "$tok" > VERSION && git commit -qam "verify $tok" && git push -q origin main </dev/null 2>/dev/null
  sleep 1
  grep -qx "$tok" /var/www/app/VERSION 2>/dev/null && pass main_deploys || fail main_deploys "a push of main did not update /var/www/app/VERSION"
  git checkout -qb lt-feature && echo "$tok-feature" > VERSION && git commit -qam feature && git push -q origin lt-feature </dev/null 2>/dev/null
  sleep 1
  if grep -qx "$tok-feature" /var/www/app/VERSION 2>/dev/null; then fail only_main "a push of another branch was deployed"; else pass only_main; fi
  git push -q origin --delete lt-feature </dev/null 2>/dev/null
else
  fail main_deploys "cannot clone deploy@server:/srv/git/app.git"
  fail only_main "not tested"
fi
cd /; rm -rf $w
[ $(( 0$(stat -c %a /var/www/app) & 002 )) -eq 0 ] && pass webroot_safe || fail webroot_safe "/var/www/app is world-writable"
if out=$(git -c safe.directory='*' --git-dir=/srv/git/app.git fsck 2>&1); then pass repo_intact; else fail repo_intact "git fsck: $(printf '%s' "$out" | head -2 | tr '\n' ' ')"; fi
