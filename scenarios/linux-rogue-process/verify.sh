# a container has no kernel threads: anything called [kworker...] is disguised (root here cannot read other users'
# /proc/PID/exe without CAP_SYS_PTRACE, so the command line is what we look at)
rogue=$(ps -eo pid=,args= | grep -E '\[kworker|\.sysupd|-c /dev/zero' | grep -v grep | awk '{print $1}' | tr '\n' ' ')
[ -z "$rogue" ] && pass process_stopped || fail process_stopped "still running: pid $rogue"
if crontab -l -u deploy 2>/dev/null | grep -v '^#' | grep -q 'sysupd'; then fail persistence_removed "deploy's crontab still starts it"; else pass persistence_removed; fi
crontab -l -u deploy 2>/dev/null | grep -q '^0 2 \* \* \* /home/deploy/bin/cleanup-builds.sh' && pass legit_job_kept || fail legit_job_kept "the nightly cleanup job of deploy is gone"
id deploy >/dev/null 2>&1 && pass account_kept || fail account_kept "the deploy account was removed"
[ ! -e /home/deploy/.cache/.sysupd/sysupd ] && pass binary_removed || fail binary_removed "the program is still on disk"
