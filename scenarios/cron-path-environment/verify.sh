# run the job the way cron does: its own variables from the file, otherwise PATH=/usr/bin:/bin
envs=$(grep -E '^[A-Za-z_]+=' /etc/cron.d/sales-report | tr '\n' ' ')
cmd=$(grep -E '^[^#A-Za-z_]' /etc/cron.d/sales-report | grep sales-report | head -1 | awk '{for(i=7;i<=NF;i++) printf "%s ", $i}')
rm -f /var/reports/sales-*
[ -n "$cmd" ] && env -i SHELL=/bin/sh PATH=/usr/bin:/bin HOME=/root $envs /bin/sh -c "$cmd" >/dev/null 2>&1
ls /var/reports/sales-* >/dev/null 2>&1 && [ -s "$(ls /var/reports/sales-* | head -1)" ] && pass job_works_in_cron || fail job_works_in_cron "the job fails in cron's environment"
grep -qE '^[^#]*[0-9*] +root +.*sales-report' /etc/cron.d/sales-report && pass still_scheduled || fail still_scheduled "the job is no longer scheduled"
