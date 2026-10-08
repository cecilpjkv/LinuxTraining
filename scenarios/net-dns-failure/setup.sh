#!/bin/bash
set -e
cat > /etc/dnsmasq.d/internal.conf <<'X'
# internal zone served by the local DNS cache
listen-address=127.0.0.1
bind-interfaces
no-resolv
host-record=api.payments.internal,10.20.30.40
host-record=db.payments.internal,10.20.30.41
X
systemctl enable --now dnsmasq
printf 'nameserver 127.0.0.1\n' > /etc/resolv.conf
getent hosts api.payments.internal >/dev/null
# the migration
systemctl disable --now dnsmasq
printf '# migrated to the datacenter DNS (MIG-221)\nnameserver 10.0.0.53\noptions timeout:1 attempts:1\n' > /etc/resolv.conf
