lt_login() { ssh -n -i /etc/lt-ssh-test/$1 -p ${2:-22} -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR "$1@127.0.0.1" true; }
new=$(comm -13 /root/.lt-suid-baseline <(find / -xdev -perm -4000 -type f 2>/dev/null | sort) | tr '\n' ' ')
[ -z "$new" ] && pass no_suid_shell || fail no_suid_shell "$new"
grep -rqs '203.0.113.66' /etc/cron.d /var/spool/cron /etc/crontab && fail no_malicious_cron "a cron job still downloads from the attacker" || pass no_malicious_cron
if systemctl is-enabled --quiet sysmetrics 2>/dev/null || systemctl is-active --quiet sysmetrics 2>/dev/null; then fail no_fake_service "sysmetrics is still installed"; else pass no_fake_service; fi
grep -qs '203.0.113.66' /home/deploy/.ssh/authorized_keys && fail no_attacker_key "the attacker's key is in deploy's authorized_keys" || pass no_attacker_key
runuser -u deploy -- sudo -n /usr/bin/id >/dev/null 2>&1 && fail no_sudo_backdoor "deploy can run anything as root" || pass no_sudo_backdoor
sshd -T 2>/dev/null | grep -qi '^permitrootlogin yes' && fail ssh_hardened "root can log in over SSH" || pass ssh_hardened
lt_login admin && id -nG admin | grep -qw wheel && pass admin_ok || fail admin_ok "admin cannot log in or lost sudo"
crontab -l -u deploy 2>/dev/null | grep -q '/home/deploy/bin/cleanup.sh' && pass legit_cron_kept || fail legit_cron_kept "deploy's cleanup job is gone"
curl -s -m 5 http://127.0.0.1:8097/ | grep -q 'web ok' && pass web_kept || fail web_kept "the web service is down"
