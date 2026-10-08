#!/bin/bash
set -e
cat > /usr/local/sbin/image-converter <<'X'
#!/usr/bin/python3
import threading, time, sys
def work():
    while True: time.sleep(1)
try:
    for i in range(40):
        threading.Thread(target=work, daemon=True).start()
except RuntimeError as e:
    sys.exit(f"image-converter: {e}")
while True:
    open("/run/image-converter.ok", "w").write(time.strftime("%T\n")); time.sleep(2)
X
chmod 755 /usr/local/sbin/image-converter
printf '[Unit]\nDescription=Image converter\nStartLimitIntervalSec=300\nStartLimitBurst=3\n\n[Service]\nExecStart=/usr/local/sbin/image-converter\nTasksMax=16\nRestart=on-failure\nRestartSec=1\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/image-converter.service
systemctl daemon-reload
systemctl enable image-converter
systemctl start image-converter || true
sleep 6
