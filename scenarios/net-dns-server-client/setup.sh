#!/bin/bash
set -e
if [ "$LT_NODE" = ns1 ]; then
  cat > /etc/dnsmasq.d/corp.conf <<'CONF'
# internal zone corp.lan (answered here; everything else is forwarded)
domain=corp.lan
local=/corp.lan/
host-record=intranet.corp.lan,10.20.30.40
host-record=api.crop.lan,10.20.30.41
host-record=git.corp.lan,10.20.30.42
CONF
  systemctl enable dnsmasq
  systemctl restart dnsmasq
else
  ns1=$(getent hosts ns1 | awk '{print $1; exit}')
  [ -n "$ns1" ]
  grep -q ns1.corp.lan /etc/hosts || echo "$ns1 ns1.corp.lan ns1" >> /etc/hosts
  # still the old DNS server (switched off)
  printf '# corp.lan resolvers\nsearch corp.lan\nnameserver 10.20.0.53\noptions timeout:1 attempts:1\n' > /etc/resolv.conf
  mkdir -p /opt/inventory-sync /var/lib/inventory
  cat > /opt/inventory-sync/sync <<'PY'
#!/usr/bin/python3
# syncs the inventory with the API every 5 seconds
import socket, time
while True:
    try:
        ip = socket.gethostbyname("api.corp.lan")
        status = f"ok {ip}"
    except OSError as e:
        status = f"error: cannot resolve api.corp.lan ({e})"
    with open("/var/lib/inventory/status", "w") as f:
        f.write(f"{int(time.time())} {status}\n")
    time.sleep(5)
PY
  chmod 755 /opt/inventory-sync/sync
  cat > /etc/systemd/system/inventory-sync.service <<'UNIT'
[Unit]
Description=Inventory sync

[Service]
ExecStart=/opt/inventory-sync/sync
Restart=always

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable --now inventory-sync
fi
