sleep 1
if [ "$LT_NODE" = web ]; then
  G="runuser -u deploy -- git -C /var/www/shop"
  if [ ! -d /var/www/shop/.git ]; then
    fail key_access "no clone in /var/www/shop"; fail cloned_branch "no clone in /var/www/shop"
  else
    url=$($G remote get-url origin 2>/dev/null)
    case "$url" in *git@git:*|ssh://git@git*) ;; *) url_bad=1;; esac
    out=$(cd /tmp && runuser -u deploy -- env GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git -C /var/www/shop ls-remote origin 2>&1)
    if [ -z "$url_bad" ] && echo "$out" | grep -q 'refs/heads/release/2.1'; then pass key_access "$url"; else fail key_access "origin ${url:-?}: $(echo "$out" | tail -1)"; fi
    br=$($G rev-parse --abbrev-ref HEAD 2>/dev/null)
    [ "$br" = release/2.1 ] && pass cloned_branch || { fail cloned_branch "checked out: ${br:-?}"; [ -n "$br" ] && deduct wrong_branch "$br"; }
  fi
  curl -s -m 5 -H 'Host: shop.example.test' http://127.0.0.1/ | grep -q 'Version 2.1' && pass site_works || fail site_works "HTTP $(http_code -H 'Host: shop.example.test' http://127.0.0.1/)"
  if [ -d /var/www/shop ]; then
    o=$(find /var/www/shop ! -user deploy | head -3); ww=$(find /var/www/shop -perm -o+w ! -type l | head -3)
    [ -z "$o$ww" ] && pass permissions || fail permissions "${o:+not owned by deploy: $(echo $o)}${ww:+ world-writable: $(echo $ww)}"
  else fail permissions "no /var/www/shop"; fi
  systemctl is-active --quiet deploy-webhook && systemctl is-enabled --quiet deploy-webhook && pass webhook_service || fail webhook_service "$(systemctl is-active deploy-webhook) / $(systemctl is-enabled deploy-webhook 2>&1)"
else
  # a developer pushes a change to release/2.1; the hook must get it onto web
  tag=lt$RANDOM$RANDOM
  w=$(mktemp -d); chown git:git $w
  runuser -u git -- bash -c "cd $w && git clone -q -b release/2.1 /srv/git/shop.git s && cd s && git config user.name 'Dev Team' && git config user.email dev@example.test &&
    sed -i 's|<p>Deployed: .*</p>|<p>Deployed: $tag</p>|' public/index.html && git commit -qam 'Hotfix $tag' && git push -q origin release/2.1" >/dev/null 2>&1 </dev/null
  rm -rf $w
  ok=""
  for i in $(seq 1 15); do curl -s -m 5 -H 'Host: shop.example.test' http://web/ | grep -q "Deployed: $tag" && { ok=1; break; }; sleep 1; done
  [ -n "$ok" ] && pass webhook_deploys || fail webhook_deploys "the push was not deployed on web within 15 s"
fi
