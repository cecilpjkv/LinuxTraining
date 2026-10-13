#!/bin/bash
set -e
rm -f /etc/ssh/sshd_config.d/*permitrootlogin*.conf
install -d -m 700 /etc/lt-ssh-test
id acme >/dev/null 2>&1 || useradd -m -s /bin/bash acme
[ -f /etc/lt-ssh-test/acme ] || ssh-keygen -q -t ed25519 -N '' -C 'orders@acme' -f /etc/lt-ssh-test/acme
install -d -m 700 -o acme -g acme /home/acme/.ssh
install -m 600 -o acme -g acme /etc/lt-ssh-test/acme.pub /home/acme/.ssh/authorized_keys
cat > /etc/ssh/sshd_config.d/60-sftp-partners.conf <<'CONF'
# SFTP-only partners: locked into /srv/sftp/<user>
Match User acme
    ChrootDirectory /srv/sftp/%u
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
CONF
# the "proper" setup: the partner owns its area, the upload folder belongs to root
install -d -m 755 /srv/sftp
install -d -m 755 -o acme -g acme /srv/sftp/acme
install -d -m 755 -o root -g root /srv/sftp/acme/upload
echo 'order-1001;2;widget' > /srv/sftp/acme/upload/orders-old.csv
systemctl enable sshd && systemctl restart sshd
for i in $(seq 1 20); do ss -ltn | grep -q ':22 ' && break; sleep 0.5; done
