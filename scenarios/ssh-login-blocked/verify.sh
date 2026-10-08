# -n: verify.sh itself arrives on stdin, which ssh would otherwise swallow
lt_login() { ssh -n -i /etc/lt-ssh-test/$1 -p ${2:-22} -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR "$1@127.0.0.1" true; }
lt_login support && pass support_login || fail support_login "support cannot log in with the key"
lt_login deploy && pass deploy_login || fail deploy_login "deploy cannot log in any more"
sshd -T 2>/dev/null | grep -qi '^permitrootlogin no' && pass root_login_disabled || fail root_login_disabled "root login is allowed"
sshd -T 2>/dev/null | grep -qi '^allowusers.*deploy' && pass allowlist_kept || fail allowlist_kept "the AllowUsers list was removed"
