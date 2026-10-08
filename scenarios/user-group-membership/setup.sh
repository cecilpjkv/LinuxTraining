#!/bin/bash
set -e
groupadd -f certs
id webproxy >/dev/null 2>&1 || useradd -r -s /sbin/nologin webproxy
mkdir -p /etc/pki/app
openssl genpkey -algorithm ed25519 -out /etc/pki/app/proxy.key 2>/dev/null
chown root:certs /etc/pki/app/proxy.key; chmod 640 /etc/pki/app/proxy.key
cat > /usr/local/sbin/tls-proxy <<'X'
#!/bin/bash
while :; do
  if head -c 1 /etc/pki/app/proxy.key >/dev/null 2>&1; then date +%s > /run/tls-proxy/ok; else echo "tls-proxy: cannot read /etc/pki/app/proxy.key: Permission denied" >&2; fi
  sleep 2
done
X
chmod 755 /usr/local/sbin/tls-proxy
printf '[Unit]\nDescription=TLS proxy\n\n[Service]\nUser=webproxy\nRuntimeDirectory=tls-proxy\nExecStart=/usr/local/sbin/tls-proxy\nRestart=always\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/tls-proxy.service
systemctl daemon-reload
systemctl enable --now tls-proxy
