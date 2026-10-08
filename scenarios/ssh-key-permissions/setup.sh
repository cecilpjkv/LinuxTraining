#!/bin/bash
set -e
# AlmaLinux images ship a NN-permitrootlogin.conf (PermitRootLogin yes): sshd takes the first value it reads, so it
# would override every later drop-in. The server's own baseline disables root login.
rm -f /etc/ssh/sshd_config.d/*permitrootlogin*.conf
# test accounts with keys (the client keys live in /etc/lt-ssh-test for the checks)
install -d -m 700 /etc/lt-ssh-test
for u in support deploy; do
  id "$u" >/dev/null 2>&1 || useradd -m -s /bin/bash "$u"
  [ -f /etc/lt-ssh-test/$u ] || ssh-keygen -q -t ed25519 -N '' -C "$u@helpdesk" -f /etc/lt-ssh-test/$u
  install -d -m 700 -o "$u" -g "$u" /home/$u/.ssh
  install -m 600 -o "$u" -g "$u" /etc/lt-ssh-test/$u.pub /home/$u/.ssh/authorized_keys
done
systemctl enable --now sshd
for i in $(seq 1 20); do ss -ltn | grep -q ':22 ' && break; sleep 0.5; done
chmod 777 /home/support /home/support/.ssh
chown root:root /home/support/.ssh/authorized_keys
chmod 666 /home/support/.ssh/authorized_keys
