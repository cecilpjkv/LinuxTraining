# reference fix (not imported; used by scripts/check_scenarios.py)
crontab -u deploy -l | grep -v sysupd | crontab -u deploy -
pkill -9 -u deploy -f -- '-c /dev/zero' || true
rm -rf /home/deploy/.cache/.sysupd
