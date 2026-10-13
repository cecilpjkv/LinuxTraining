# reference fix (not imported; used by scripts/check_scenarios.py). The git server runs first: it accepts a key made
# there and hands it to web (as setup.sh would); web then clones and installs the hook over that same SSH access.
if [ "$LT_NODE" = git ]; then
  k=$(mktemp -d); ssh-keygen -q -t ed25519 -N '' -C deploy@web -f $k/key
  cat $k/key.pub >> /home/git/.ssh/authorized_keys; chown git:git /home/git/.ssh/authorized_keys; chmod 600 /home/git/.ssh/authorized_keys
  echo "@@LT SHARE DEPLOY_KEY $(base64 -w0 < $k/key)"
  rm -rf $k
else
  install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
  printf '%s' "$LT_SHARE_DEPLOY_KEY" | base64 -d > /home/deploy/.ssh/id_ed25519
  chown deploy:deploy /home/deploy/.ssh/id_ed25519; chmod 600 /home/deploy/.ssh/id_ed25519
  runuser -u deploy -- sh -c 'ssh-keyscan -q git >> ~/.ssh/known_hosts 2>/dev/null'
  install -d -o deploy -g deploy /var/www/shop
  runuser -u deploy -- git clone -q -b release/2.1 git@git:/srv/git/shop.git /var/www/shop
  systemctl enable --now deploy-webhook
  printf '#!/bin/sh\ncurl -s -m 30 -X POST -H "X-Deploy-Token: %s" http://web:9000/hooks/deploy >/dev/null\n' "$(cat /etc/deploy-webhook/token)" |
    runuser -u deploy -- ssh -o BatchMode=yes git@git 'cat > /srv/git/shop.git/hooks/post-receive && chmod 755 /srv/git/shop.git/hooks/post-receive'
  sleep 1
fi
