#!/bin/bash
set -e
cat > /usr/local/sbin/orders-queue <<'X'
#!/bin/bash
exec sleep infinity
X
cat > /usr/local/sbin/orders-worker <<'X'
#!/bin/bash
[ -f /run/orders-queue/ready ] || { echo "orders-worker: queue is not running (/run/orders-queue/ready missing)" >&2; exit 1; }
while :; do date +%s > /run/orders-worker.ok; sleep 2; done
X
chmod 755 /usr/local/sbin/orders-queue /usr/local/sbin/orders-worker
printf '[Unit]\nDescription=Orders queue\n\n[Service]\nExecStartPre=/bin/sh -c "mkdir -p /run/orders-queue; echo ready > /run/orders-queue/ready"\nExecStart=/usr/local/sbin/orders-queue\nExecStopPost=/bin/rm -f /run/orders-queue/ready\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/orders-queue.service
printf '[Unit]\nDescription=Orders worker\n\n[Service]\nExecStart=/usr/local/sbin/orders-worker\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/orders-worker.service
systemctl daemon-reload
systemctl enable orders-queue orders-worker
systemctl start orders-queue orders-worker
