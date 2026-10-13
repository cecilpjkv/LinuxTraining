# reference fix: use python3 (python is not installed) and run from the app's directory
mkdir -p /etc/systemd/system/pyapp.service.d
cat > /etc/systemd/system/pyapp.service.d/override.conf <<'OVR'
[Service]
WorkingDirectory=/opt/pyapp
ExecStart=
ExecStart=/usr/bin/python3 /opt/pyapp/app.py
OVR
systemctl daemon-reload
systemctl restart pyapp
sleep 2
