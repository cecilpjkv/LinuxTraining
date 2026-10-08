lt_login() { ssh -n -i /etc/lt-ssh-test/$1 -p ${2:-22} -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR "$1@127.0.0.1" true; }
getent passwd support >/dev/null && pass users_resolve || fail users_resolve "support is unknown to the system"
lt_login support && pass ssh_works || fail ssh_works "support cannot log in"
sleep 1
curl -s -m 5 http://127.0.0.1:8095/ | grep -q 'ledger ok' && pass service_works || fail service_works "ledger-api is not answering"
