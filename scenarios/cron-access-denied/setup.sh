#!/bin/bash
set -e
id reports >/dev/null 2>&1 || useradd -m -s /bin/bash reports
printf 'root\nbackup\n' > /etc/cron.allow
chmod 600 /etc/cron.allow
chmod u-s /usr/bin/crontab
