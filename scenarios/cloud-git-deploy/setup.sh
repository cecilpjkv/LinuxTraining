#!/bin/bash
set -e
if [ "$LT_NODE" = git ]; then
  id git >/dev/null 2>&1 || useradd -m -d /home/git -s /bin/bash git
  passwd -l git >/dev/null
  install -d -m 700 -o git -g git /home/git/.ssh
  install -d -o git -g git /srv/git
  runuser -u git -- git init -q --bare -b main /srv/git/shop.git
  w=$(mktemp -d); chown git:git $w
  runuser -u git -- bash -c "
    set -e; cd $w; git init -q -b main; git config user.name 'Dev Team'; git config user.email dev@example.test
    mkdir -p public; echo '<!doctype html><title>Shop</title><h1>Example Shop</h1><p>Version 1.9</p>' > public/index.html
    echo '# Example Shop' > README.md; git add -A; git commit -qm 'Shop 1.9'
    git checkout -q -b release/2.1
    echo '<!doctype html><title>Shop</title><h1>Example Shop</h1><p>Version 2.1</p><p>Deployed: initial</p>' > public/index.html
    echo 'body { font-family: sans-serif }' > public/site.css; git add -A; git commit -qm 'Release 2.1'
    git checkout -q main; git checkout -q -b develop
    echo '<!doctype html><title>Shop</title><h1>Example Shop</h1><p>Version 2.2-dev</p>' > public/index.html
    git commit -qam 'Work in progress 2.2'
    git push -q /srv/git/shop.git main release/2.1 develop"
  rm -rf $w
  systemctl restart sshd
else
  id deploy >/dev/null 2>&1 || useradd -m -s /bin/bash deploy
  grep -q 'shop.example.test' /etc/hosts || echo '127.0.0.1 shop.example.test' >> /etc/hosts
  cat > /etc/nginx/conf.d/shop.conf <<'CONF'
server {
    listen 80;
    server_name shop.example.test;
    root /var/www/shop/public;
    index index.html;
}
CONF
  install -d -m 755 /var/www
  mkdir -p /etc/deploy-webhook
  openssl rand -hex 16 > /etc/deploy-webhook/token
  chown root:deploy /etc/deploy-webhook/token && chmod 640 /etc/deploy-webhook/token
  cat > /usr/local/bin/deploy-webhook <<'PY'
#!/usr/bin/python3
"""Deploy webhook: POST /hooks/deploy with the header X-Deploy-Token pulls the latest code into /var/www/shop."""
import http.server, subprocess, sys
TOKEN = open('/etc/deploy-webhook/token').read().strip()
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != '/hooks/deploy':
            self.send_response(404); self.end_headers(); return
        if self.headers.get('X-Deploy-Token', '') != TOKEN:
            print('rejected: wrong token from', self.client_address[0], flush=True)
            self.send_response(403); self.end_headers(); self.wfile.write(b'forbidden\n'); return
        r = subprocess.run(['git', '-C', '/var/www/shop', 'pull', '--ff-only'], capture_output=True, text=True, timeout=60)
        print('deploy requested by', self.client_address[0], '->', r.returncode, (r.stdout + r.stderr).strip(), flush=True)
        self.send_response(200 if r.returncode == 0 else 500); self.end_headers()
        self.wfile.write((r.stdout + r.stderr).encode())
    def log_message(self, *a):
        pass
http.server.ThreadingHTTPServer(('0.0.0.0', 9000), H).serve_forever()
PY
  chmod 755 /usr/local/bin/deploy-webhook
  cat > /etc/systemd/system/deploy-webhook.service <<'UNIT'
[Unit]
Description=Deploy webhook for the shop
After=network.target
[Service]
User=deploy
ExecStart=/usr/local/bin/deploy-webhook
Restart=on-failure
[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable --now nginx
fi
