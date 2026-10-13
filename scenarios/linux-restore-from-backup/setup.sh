#!/bin/bash
set -e
id booking >/dev/null 2>&1 || useradd -r -s /sbin/nologin -d /var/lib/booking booking
install -d -o booking -g booking -m 750 /var/lib/booking
install -d -o root -g booking -m 750 /etc/booking /etc/booking/secrets
cat > /etc/booking/app.conf <<'CONF'
# booking service
listen = 127.0.0.1:8085
db_host = db01.internal
db_name = booking
max_parallel_bookings = 25
CONF
cat > /etc/booking/rooms.conf <<'CONF'
# bookable rooms
A101 = 12
A102 = 8
B201 = 30
CONF
head -c 24 /dev/urandom | base64 > /etc/booking/secrets/api.key
chown root:booking /etc/booking/app.conf /etc/booking/rooms.conf
chmod 640 /etc/booking/app.conf /etc/booking/rooms.conf
chown booking:booking /etc/booking/secrets/api.key
chmod 600 /etc/booking/secrets/api.key
mkdir -p /var/lib/lt-booking && chmod 700 /var/lib/lt-booking
( cd /etc/booking && find . -type f -exec sha256sum {} + | sort -k2 ) > /var/lib/lt-booking/sums
( cd /etc/booking && find . -printf '%p %u %g %m\n' | sort ) > /var/lib/lt-booking/modes
cat > /usr/local/bin/booking <<'PY'
#!/usr/bin/python3
# the booking service: needs its configuration and API key
import http.server, sys
conf = {k.strip(): v.strip() for k, v in (l.split("=", 1) for l in open("/etc/booking/app.conf") if "=" in l and not l.startswith("#"))}
key = open("/etc/booking/secrets/api.key").read().strip()
rooms = [l for l in open("/etc/booking/rooms.conf") if "=" in l and not l.startswith("#")]
host, port = conf["listen"].split(":")
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(f"booking ok, {len(rooms)} rooms\n".encode())
    def log_message(self, *a): pass
http.server.HTTPServer((host, int(port)), H).serve_forever()
PY
chmod 755 /usr/local/bin/booking
cat > /etc/systemd/system/booking.service <<'UNIT'
[Unit]
Description=Booking service

[Service]
User=booking
ExecStart=/usr/local/bin/booking
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now booking
for i in $(seq 1 20); do curl -s -m 2 http://127.0.0.1:8085/ | grep -q 'booking ok' && break; sleep 0.5; done
curl -s -m 2 http://127.0.0.1:8085/ | grep -q 'booking ok'  # the working state, before the accident
# nightly backups: two good ones, and last night's, which was cut off when the disk filled up
mkdir -p /var/backups/booking
for d in 3 2; do
  tar -czpf /var/backups/booking/etc-booking-$(date -d "-$d day" +%F).tar.gz -C / etc/booking
  touch -d "-$d day 02:00" /var/backups/booking/etc-booking-$(date -d "-$d day" +%F).tar.gz
done
tar -czpf - -C / etc/booking | head -c 300 > /var/backups/booking/etc-booking-$(date -d '-1 day' +%F).tar.gz
touch -d "-1 day 02:00" /var/backups/booking/etc-booking-$(date -d '-1 day' +%F).tar.gz
chmod 600 /var/backups/booking/*
rm -rf /etc/booking
systemctl restart booking 2>/dev/null || true
