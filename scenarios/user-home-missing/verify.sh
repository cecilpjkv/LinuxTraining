lt_login_u() { ssh -n -i /etc/lt-ssh-test/$1 -p ${2:-22} -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR "$1@127.0.0.1" true; }
lt_login() { lt_login_u "$@"; }
lt_login analyst && pass key_login || fail key_login "analyst cannot log in with the key"
h=/home/analyst
if [ -d $h ] && [ "$(stat -c %U $h)" = analyst ] && [ $(( 0$(stat -c %a $h) & 077 )) -eq 0 ]; then pass home_private; else fail home_private "$h missing, not owned by analyst or open to others"; fi
[ -f $h/.bashrc ] && pass profile_files || fail profile_files "no .bashrc (skeleton files missing)"
