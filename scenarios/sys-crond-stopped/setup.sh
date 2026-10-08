#!/bin/bash
set -e
printf '* * * * * root date +%%s > /var/lib/heartbeat\n' > /etc/cron.d/heartbeat
systemctl disable --now crond
