#!/bin/bash
set -e
git config --global user.name "Site Admin"
git config --global user.email "admin@example.test"
git config --global init.defaultBranch main
git config --global pull.rebase false
git init -q --bare /srv/git/site.git
w=$(mktemp -d)
git clone -q /srv/git/site.git $w/dev 2>/dev/null
cd $w/dev
cat > index.html <<'HTML'
<!doctype html>
<title>Example Corp</title>
<h1>Example Corp</h1>
<p>Release 2.2</p>
<p>We build things.</p>
<footer>Call us: 555-0100 | (c) 2025 Example Corp</footer>
HTML
echo 'body { font-family: sans-serif }' > style.css
git add . && git commit -qm "Release 2.2" && git push -q origin main
git clone -q /srv/git/site.git /srv/site
# last week: an urgent change made directly on the server, committed but never pushed
cd /srv/site
sed -i 's/Call us: 555-0100/Call us: 555-0199/' index.html
git commit -qam "Hotfix: new support phone number"
git rev-parse HEAD > /var/lib/.lt-hotfix
# release 2.3 from the developers
cd $w/dev
sed -i 's/Release 2.2/Release 2.3/; s/(c) 2025/(c) 2026/; s/We build things./We build better things./' index.html
git commit -qam "Release 2.3" && git push -q origin main
rm -rf $w
# this morning's deploy
cd /srv/site
git pull -q origin main >/dev/null 2>&1 || true
cat > /etc/systemd/system/site.service <<'UNIT'
[Unit]
Description=Company site (static, from /srv/site)

[Service]
ExecStart=/usr/bin/python3 -m http.server 8000 --bind 127.0.0.1 --directory /srv/site
Restart=always

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now site
