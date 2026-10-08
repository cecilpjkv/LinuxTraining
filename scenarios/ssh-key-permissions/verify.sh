# -n: verify.sh itself arrives on stdin, which ssh would otherwise swallow
lt_login() { ssh -n -i /etc/lt-ssh-test/$1 -p ${2:-22} -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR "$1@127.0.0.1" true; }
lt_login support && pass key_login || fail key_login "support cannot log in with the key"
sshd -T 2>/dev/null | grep -qi '^strictmodes yes' && pass strict_modes_kept || fail strict_modes_kept "StrictModes was turned off"
bad=""
for p in /home/support /home/support/.ssh /home/support/.ssh/authorized_keys; do
  m=$(stat -c %a "$p"); o=$(stat -c %U "$p")
  [ $(( 0$m & 022 )) -ne 0 ] && bad="$bad $p(mode $m)"
  [ "$o" != support ] && bad="$bad $p(owner $o)"
done
[ -z "$bad" ] && pass safe_permissions || fail safe_permissions "$bad"
