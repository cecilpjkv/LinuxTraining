lt_login() { ssh -n -i /etc/lt-ssh-test/$1 -p ${2:-22} -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR "$1@127.0.0.1" true; }
lt_login support && pass key_login || fail key_login "support cannot log in"
exp=$(chage -l support | awk -F': ' '/^Account expires/{print $2}')
[ "$exp" = never ] && pass not_expiring "never" || { [ -n "$exp" ] && [ "$(date -d "$exp" +%s 2>/dev/null || echo 0)" -gt "$(date +%s)" ] && pass not_expiring "$exp" || fail not_expiring "expires: $exp"; }
