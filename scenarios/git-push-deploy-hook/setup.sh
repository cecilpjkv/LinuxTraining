#!/bin/bash
set -e
rm -f /etc/ssh/sshd_config.d/*permitrootlogin*.conf
git config --global user.name "Release Bot"
git config --global user.email "release@example.test"
git config --global init.defaultBranch main
id deploy >/dev/null 2>&1 || useradd -m -s /bin/bash deploy
install -d -m 700 /etc/lt-ssh-test
[ -f /etc/lt-ssh-test/dev ] || ssh-keygen -q -t ed25519 -N '' -C 'developer@laptop' -f /etc/lt-ssh-test/dev
install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
install -m 600 -o deploy -g deploy /etc/lt-ssh-test/dev.pub /home/deploy/.ssh/authorized_keys
install -d -o deploy -g deploy /srv/git
sudo -u deploy git init -q --bare /srv/git/app.git
cat > /srv/git/app.git/hooks/post-receive <<'HOOK'
#!/bin/bash
# deploy the master branch to the web root on every push
while read oldrev newrev ref; do
  if [ "$ref" = "refs/heads/master" ]; then
    git --work-tree=/var/www/app --git-dir=/srv/git/app.git checkout -f master
    echo "deployed $newrev to /var/www/app"
  fi
done
HOOK
chown deploy:deploy /srv/git/app.git/hooks/post-receive
chmod 644 /srv/git/app.git/hooks/post-receive
# the web root came over from the old server owned by root
install -d -m 755 -o root -g root /var/www/app
echo '1.0.0 (old server)' > /var/www/app/VERSION
systemctl enable sshd && systemctl restart sshd
for i in $(seq 1 20); do ss -ltn | grep -q ':22 ' && break; sleep 0.5; done
# a developer's push since the migration (accepted, never deployed)
w=$(mktemp -d)
cd $w && git init -q app && cd app
echo '1.4.0' > VERSION && echo 'print("hello")' > app.py
git add . && git commit -qm "Release 1.4.0"
GIT_SSH_COMMAND="ssh -i /etc/lt-ssh-test/dev -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR" \
  git push -q deploy@127.0.0.1:/srv/git/app.git main </dev/null
rm -rf $w
