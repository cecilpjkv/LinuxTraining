logger -t lt-verify "persistence probe"; sleep 1; journalctl --flush 2>/dev/null
st=$(systemd-analyze cat-config systemd/journald.conf 2>/dev/null | grep -E '^Storage=' | tail -1)
case "$st" in Storage=persistent|Storage=auto) pass config_persistent "$st";; *) fail config_persistent "${st:-Storage not set}";; esac
ls /var/log/journal/*/system.journal >/dev/null 2>&1 && pass on_disk || fail on_disk "no journal files under /var/log/journal"
