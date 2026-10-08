#!/bin/bash
set -e
rm -f /etc/ssh/sshd_config.d/*permitrootlogin*.conf
install -d -m 700 /etc/lt-ssh-test
for u in support deploy; do
  id "$u" >/dev/null 2>&1 || useradd -m -s /bin/bash "$u"
  [ -f /etc/lt-ssh-test/$u ] || ssh-keygen -q -t ed25519 -N '' -C "$u@helpdesk" -f /etc/lt-ssh-test/$u
  install -d -m 700 -o "$u" -g "$u" /home/$u/.ssh
  install -m 600 -o "$u" -g "$u" /etc/lt-ssh-test/$u.pub /home/$u/.ssh/authorized_keys
done
systemctl enable --now sshd
for i in $(seq 1 20); do ss -ltn | grep -q ':22 ' && break; sleep 0.5; done
cat > /usr/local/sbin/ledger-api <<'PYX'
#!/usr/bin/python3
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b"ledger ok\n")
    def log_message(self, *a): pass
HTTPServer((os.environ.get("BIND", "127.0.0.1"), int(os.environ.get("PORT", "8095"))), H).serve_forever()
PYX
chmod 755 /usr/local/sbin/ledger-api
printf '[Unit]\nDescription=ledger-api\n\n[Service]\nUser=support
ExecStart=/usr/local/sbin/ledger-api\nRestart=always\nRestartSec=1\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/ledger-api.service
systemctl daemon-reload
systemctl enable --now ledger-api
cp /etc/nsswitch.conf /root/.lt-nsswitch.orig
sed -i 's/^passwd:.*/passwd:     ldap/; s/^group:.*/group:      ldap/; s/^shadow:.*/shadow:     ldap/' /etc/nsswitch.conf
systemctl restart ledger-api || true
