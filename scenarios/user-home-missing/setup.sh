#!/bin/bash
set -e
rm -f /etc/ssh/sshd_config.d/*permitrootlogin*.conf
install -d -m 700 /etc/lt-ssh-test /root/keys
id analyst >/dev/null 2>&1 || useradd -m -s /bin/bash analyst
ssh-keygen -q -t ed25519 -N '' -C analyst -f /etc/lt-ssh-test/analyst
cp /etc/lt-ssh-test/analyst.pub /root/keys/analyst.pub
systemctl enable --now sshd
for i in $(seq 1 20); do ss -ltn | grep -q ':22 ' && break; sleep 0.5; done
rm -rf /home/analyst
