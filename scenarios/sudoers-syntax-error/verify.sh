check sudoers_valid visudo -c
runuser -u ops1 -- sudo -n /usr/bin/systemctl --version >/dev/null 2>&1 && pass ops_can_systemctl || fail ops_can_systemctl "ops1 cannot run systemctl with sudo"
runuser -u ops1 -- sudo -n /usr/bin/id >/dev/null 2>&1 && fail least_privilege "ops1 can run other commands" || pass least_privilege
