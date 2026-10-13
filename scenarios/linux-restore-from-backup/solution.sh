# reference fix (not imported; used by scripts/check_scenarios.py)
good=$(ls /var/backups/booking/etc-booking-*.tar.gz | sort | while read f; do tar -tzf "$f" >/dev/null 2>&1 && echo "$f"; done | tail -1)
tar -xzpf "$good" -C /
systemctl restart booking
sleep 2
