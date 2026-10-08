# -n: verify.sh itself arrives on stdin, which ssh would otherwise swallow
lt_login() { ssh -n -i /etc/lt-ssh-test/$1 -p ${2:-22} -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR "$1@127.0.0.1" true; }
check config_valid sshd -t
check sshd_running systemctl is-active --quiet sshd
lt_login support && pass key_login || fail key_login "support cannot log in with the key"
sshd -T 2>/dev/null | grep -qi '^permitrootlogin no' && pass root_login_disabled || fail root_login_disabled "root login is allowed"
