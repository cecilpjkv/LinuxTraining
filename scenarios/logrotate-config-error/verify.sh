logrotate -d -s /tmp/.lt-lr /etc/logrotate.conf >/dev/null 2>&1 && pass config_valid || fail config_valid "logrotate reports errors"
grep -Eq '^\s*(daily|weekly|monthly)' /etc/logrotate.d/payments 2>/dev/null && grep -q '/var/log/payments' /etc/logrotate.d/payments && pass payments_rule || fail payments_rule "the payments rule is missing or has no valid schedule"
logrotate -f -s /tmp/.lt-lr2 /etc/logrotate.d/payments >/dev/null 2>&1 && ls /var/log/payments/ | grep -q 'payments.log.1' && pass rotation_works || fail rotation_works "the payments log does not rotate"
rm -f /tmp/.lt-lr /tmp/.lt-lr2
