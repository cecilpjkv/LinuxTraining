#!/bin/bash
set -e
cat > /usr/local/sbin/inventory-db <<'X'
#!/usr/bin/python3
import socketserver
class H(socketserver.BaseRequestHandler):
    def handle(self): self.request.sendall(b"INVENTORY-DB READY\n")
socketserver.TCPServer.allow_reuse_address = True
socketserver.TCPServer(("127.0.0.1", 6000), H).serve_forever()
X
cat > /usr/local/sbin/inventory-sync <<'X'
#!/usr/bin/python3
import socket, sys, time
while True:
    try:
        with socket.create_connection(("db.internal", 6000), timeout=3) as s:
            if s.recv(64).startswith(b"INVENTORY-DB READY"):
                open("/run/inventory-sync.ok", "w").write(time.strftime("%F %T\n"))
    except OSError as e:
        print(f"inventory-sync: cannot connect to db.internal:6000: {e}", file=sys.stderr, flush=True)
    time.sleep(2)
X
chmod 755 /usr/local/sbin/inventory-db /usr/local/sbin/inventory-sync
for s in inventory-db inventory-sync; do
  printf '[Unit]\nDescription=%s\n\n[Service]\nExecStart=/usr/local/sbin/%s\nRestart=always\n\n[Install]\nWantedBy=multi-user.target\n' $s $s > /etc/systemd/system/$s.service
done
printf '10.9.9.9    db.internal    # inventory database (rack B)\n' >> /etc/hosts
systemctl daemon-reload
systemctl enable --now inventory-db inventory-sync
