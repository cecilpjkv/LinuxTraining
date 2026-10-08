runuser -u deploy -- sudo -n /usr/bin/systemctl restart shop-api >/dev/null 2>&1 && pass deploy_can_restart || fail deploy_can_restart "deploy cannot run the restart"
runuser -u deploy -- sudo -n /usr/bin/id >/dev/null 2>&1 && fail no_extra_rights "deploy can run other commands as root" || pass no_extra_rights
m=$(stat -c %a /etc/sudoers.d/deploy 2>/dev/null)
case "$m" in 440|400|600|640) pass safe_mode "$m";; *) fail safe_mode "mode $m";; esac
check sudoers_valid visudo -c
