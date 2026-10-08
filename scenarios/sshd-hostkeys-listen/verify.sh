lt_login() { ssh -n -i /etc/lt-ssh-test/$1 -p ${2:-22} -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR "$1@127.0.0.1" true; }
check config_valid sshd -t
check sshd_running systemctl is-active --quiet sshd
lt_login support && pass key_login || fail key_login "support cannot log in"
sha256sum -c --quiet /root/.lt-hostkeys.sha256 >/dev/null 2>&1 && pass same_host_keys || fail same_host_keys "the host keys were replaced"
bad=$(stat -c '%a %n' /etc/ssh/ssh_host_*_key | awk '$1 !~ /^[46][04]0$/ {print $2}' | tr '\n' ' ')
[ -z "$bad" ] && pass keys_private || fail keys_private "too open: $bad"
