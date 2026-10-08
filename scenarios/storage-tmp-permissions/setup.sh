#!/bin/bash
set -e
id reports >/dev/null 2>&1 || useradd -r -s /sbin/nologin reports
cat > /usr/local/sbin/report-builder <<'X'
#!/bin/bash
while :; do
  if t=$(mktemp) && echo report > "$t" && rm -f "$t"; then date '+%F %T' > /run/report-builder/ok; else echo "report-builder: cannot create a temporary file" >&2; fi
  sleep 2
done
X
chmod 755 /usr/local/sbin/report-builder
printf '[Unit]\nDescription=Report builder\n\n[Service]\nUser=reports\nRuntimeDirectory=report-builder\nExecStart=/usr/local/sbin/report-builder\nRestart=always\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/report-builder.service
systemctl daemon-reload
chmod 755 /tmp
systemctl enable --now report-builder
