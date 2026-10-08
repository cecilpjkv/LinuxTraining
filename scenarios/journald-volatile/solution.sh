# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/^Storage=volatile/Storage=persistent/' /etc/systemd/journald.conf.d/50-small-disk.conf
mkdir -p /var/log/journal
systemctl restart systemd-journald
journalctl --flush
