# reference fix (not imported; used by scripts/check_scenarios.py)
mkdir -p /etc/systemd/system/image-converter.service.d
printf '[Service]\nTasksMax=128\n' > /etc/systemd/system/image-converter.service.d/tasks.conf
systemctl daemon-reload
systemctl reset-failed image-converter
systemctl restart image-converter
