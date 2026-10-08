#!/bin/bash
set -e
useradd -r -s /sbin/nologin reports 2>/dev/null || true
mkdir -p /opt/reports/bin /var/lib/reports
cat > /opt/reports/bin/report-generator <<'X'
#!/bin/bash
# report-generator 2.3: exports the daily sales report.
# (retries the export until it succeeds)
while :; do :; done
X
cat > /opt/reports/bin/metrics-agent <<'X'
#!/usr/bin/python3
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b"metrics ok\n")
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", 9100), H).serve_forever()
X
chmod 755 /opt/reports/bin/*
cat > /etc/systemd/system/report-generator.service <<'X'
[Unit]
Description=Daily sales report generator
After=network.target

[Service]
User=reports
ExecStart=/opt/reports/bin/report-generator
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
X
cat > /etc/systemd/system/metrics-agent.service <<'X'
[Unit]
Description=Metrics agent (port 9100)

[Service]
ExecStart=/opt/reports/bin/metrics-agent
Restart=on-failure

[Install]
WantedBy=multi-user.target
X
systemctl daemon-reload
systemctl enable --now metrics-agent report-generator
sleep 2
