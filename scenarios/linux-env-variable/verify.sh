sleep 5
systemctl is-active --quiet billing-worker && pass worker_running || fail worker_running "billing-worker is not running"
n=$(ls /var/spool/billing/done 2>/dev/null | wc -l)
[ "$n" -ge 3 ] && pass jobs_processed "$n jobs done" || fail jobs_processed "$n of 3 queued jobs processed"
grep -Eq '^APP_MODE=("|)production("|)$' /etc/billing/billing.env && pass mode_fixed || fail mode_fixed "APP_MODE is not production"
