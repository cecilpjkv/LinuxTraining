# reference fix (not imported; used by scripts/check_scenarios.py)
mkdir -p /etc/systemd/system/orders-worker.service.d
printf '[Unit]\nRequires=orders-queue.service\nAfter=orders-queue.service\n' > /etc/systemd/system/orders-worker.service.d/queue.conf
systemctl daemon-reload
