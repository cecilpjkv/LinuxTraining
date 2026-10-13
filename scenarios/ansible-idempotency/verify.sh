export LC_ALL=C.UTF-8 LANG=C.UTF-8 HOME=/root
cd /srv/ansible
out1=$(timeout 120 ansible-playbook hardening.yml </dev/null 2>&1); rc1=$?
[ $rc1 -eq 0 ] && pass playbook_runs || fail playbook_runs "$(printf '%s' "$out1" | grep -m1 -E 'fatal|ERROR')"
out2=$(timeout 120 ansible-playbook hardening.yml </dev/null 2>&1); rc2=$?
recap=$(printf '%s' "$out2" | grep -E '^localhost\s*:')
if [ $rc1 -eq 0 ] && [ $rc2 -eq 0 ] && printf '%s' "$recap" | grep -q 'changed=0 '; then pass idempotent; else fail idempotent "repeated run: rc $rc2 ${recap}"; fi
f=/etc/ssh/sshd_config.d/50-hardening.conf
bad=""
for l in 'MaxAuthTries 3' 'PermitRootLogin prohibit-password' 'X11Forwarding no'; do
  [ "$(grep -cx "$l" $f 2>/dev/null)" = 1 ] || bad="$bad [$l x$(grep -cx "$l" $f 2>/dev/null)]"
done
[ "$(grep -cx 'Authorized use only. Activity is logged.' /etc/issue.net 2>/dev/null)" = 1 ] || bad="$bad [banner x$(grep -cx 'Authorized use only. Activity is logged.' /etc/issue.net)]"
[ -z "$bad" ] && pass no_duplicates || fail no_duplicates "$bad"
if sshd -t 2>/dev/null && systemctl is-active --quiet sshd && sshd -T 2>/dev/null | grep -qx 'maxauthtries 3' && id deploy >/dev/null 2>&1; then pass state_ok; else fail state_ok "sshd is not running hardened, or the deploy user is missing"; fi
