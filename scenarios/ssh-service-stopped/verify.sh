# -n: verify.sh itself arrives on stdin, which ssh would otherwise swallow
lt_login() { ssh -n -i /etc/lt-ssh-test/$1 -p ${2:-22} -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR "$1@127.0.0.1" true; }
check sshd_running systemctl is-active --quiet sshd
check sshd_enabled systemctl is-enabled --quiet sshd
ss -ltn | grep -Eq '[:.]22 ' && pass listening || fail listening "nothing listens on port 22"
lt_login support && pass key_login || fail key_login "support cannot log in with the key"
