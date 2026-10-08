#!/bin/bash
set -e
mkdir -p /etc/systemd/journald.conf.d
printf '# tuning for small disks\n[Journal]\nStorage=volatile\nRuntimeMaxUse=16M\n' > /etc/systemd/journald.conf.d/50-small-disk.conf
rm -rf /var/log/journal
systemctl restart systemd-journald
