systemctl stop orders-worker orders-queue; rm -f /run/orders-worker.ok
systemctl start orders-worker; sleep 3
[ -f /run/orders-worker.ok ] && [ $(( $(date +%s) - $(stat -c %Y /run/orders-worker.ok) )) -lt 6 ] && pass starts_alone || fail starts_alone "starting only the worker does not work"
systemctl show -p Requires,Wants,BindsTo orders-worker | grep -q orders-queue && pass dependency_declared || fail dependency_declared "the worker does not require the queue"
systemctl show -p After orders-worker | grep -q orders-queue && pass ordering_declared || fail ordering_declared "the worker is not ordered after the queue"
check worker_enabled systemctl is-enabled --quiet orders-worker
