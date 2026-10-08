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
sha256sum /etc/ssh/ssh_host_*_key > /root/.lt-hostkeys.sha256
chmod 644 /etc/ssh/ssh_host_*_key
chgrp root /etc/ssh/ssh_host_*_key
printf '# restrict sshd to the management network\nListenAddress 10.99.99.10\n' > /etc/ssh/sshd_config.d/20-listen.conf
systemctl restart sshd || true
