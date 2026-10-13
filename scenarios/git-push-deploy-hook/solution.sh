# reference fix (not imported; used by scripts/check_scenarios.py)
chmod 755 /srv/git/app.git/hooks/post-receive
sed -i 's|refs/heads/master|refs/heads/main|; s/checkout -f master/checkout -f main/; s/deploy the master branch/deploy the main branch/' /srv/git/app.git/hooks/post-receive
chown -R deploy:deploy /var/www/app
