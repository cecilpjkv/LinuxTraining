lt_login() { ssh -n -i /etc/lt-ssh-test/$1 -p ${2:-22} -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR "$1@127.0.0.1" true; }
uid0=$(awk -F: '$3==0 && $1!="root"{print $1}' /etc/passwd | tr '\n' ' ')
[ -z "$uid0" ] && pass no_extra_root || fail no_extra_root "UID 0 accounts: $uid0"
new=$(comm -13 /root/.lt-suid-baseline <(find / -xdev -perm -4000 -type f 2>/dev/null | sort) | tr '\n' ' ')
[ -z "$new" ] && pass no_suid_backdoor || fail no_suid_backdoor "new SUID files: $new"
grep -q '203.0.113.66' /root/.ssh/authorized_keys 2>/dev/null && fail no_attacker_key "the attacker's key is in root's authorized_keys" || pass no_attacker_key
lt_login admin && pass admin_login || fail admin_login "admin cannot log in"
id -nG admin | grep -qw wheel && pass admin_sudo || fail admin_sudo "admin is not in wheel"
