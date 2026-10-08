#!/bin/bash
set -e
chmod 755 /var/log/app   # a normal log volume (the bare tmpfs is world-writable)
cat > /etc/ledger-sync.conf <<'X'
# ledger-sync settings
LOG_LEVEL=DEBUG
LOG_FILE=/var/log/app/ledger-sync.log
X
cat > /usr/local/bin/ledger-sync <<'X'
#!/usr/bin/python3
import os, sys, time
cfg = dict(l.strip().split("=", 1) for l in open("/etc/ledger-sync.conf") if "=" in l and not l.startswith("#"))
debug = cfg.get("LOG_LEVEL", "INFO").upper() == "DEBUG"
log = open(cfg["LOG_FILE"], "a")
n = 0
while True:
    n += 1
    try:
        if debug:
            log.write(("%s DEBUG ledger row %d payload=%s\n" % (time.strftime("%F %T"), n, "x" * 900)) * 20)
        if n % 10 == 0:
            log.write("%s INFO synced batch %d\n" % (time.strftime("%F %T"), n))
        log.flush()
        open("/run/ledger-sync.ok", "w").write(time.strftime("%F %T\n"))
    except OSError as e:
        print("ledger-sync: write failed: %s" % e, file=sys.stderr, flush=True)
    time.sleep(1)
X
chmod 755 /usr/local/bin/ledger-sync
cat > /etc/logrotate.d/ledger-sync <<'X'
/var/log/ledger-sync.log {
    size 5M
    rotate 3
    compress
    copytruncate
    missingok
}
X
cat > /etc/systemd/system/ledger-sync.service <<'X'
[Unit]
Description=Ledger sync

[Service]
ExecStart=/usr/local/bin/ledger-sync
Restart=always

[Install]
WantedBy=multi-user.target
X
head -c 31M /dev/zero | tr '\0' 'd' > /var/log/app/ledger-sync.log || true
systemctl daemon-reload
systemctl enable --now ledger-sync
sleep 2
cat /dev/zero >> /var/log/app/ledger-sync.log 2>/dev/null || true   # the volume is now completely full
sleep 2
rm -f /run/ledger-sync.ok
