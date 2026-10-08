#!/bin/sh
# Installs the separate Docker daemon that runs the training labs:
#  - user-namespace remapping: root inside a lab is uid 200000+ on the host;
#  - its own network namespace (ltlabs, entered with nsenter): labs reach nothing outside themselves, and this daemon cannot
#    touch the host's interfaces (two dockerds in one namespace fight over docker0);
#  - no firewall management (the main daemon owns the Docker nftables tables).
# The application's own containers stay on the normal Docker daemon; the backend only gets this daemon's socket
# (/run/lt-labs/docker.sock).
set -eu
cd "$(dirname "$0")"
id dockremap >/dev/null 2>&1 || useradd -r -s /sbin/nologin dockremap
grep -q '^dockremap:' /etc/subuid || echo 'dockremap:200000:65536' >> /etc/subuid
grep -q '^dockremap:' /etc/subgid || echo 'dockremap:200000:65536' >> /etc/subgid
install -d -m 0755 /etc/docker-labs
changed=0
cmp -s daemon.json /etc/docker-labs/daemon.json || { install -m 0644 daemon.json /etc/docker-labs/daemon.json; changed=1; }
cmp -s docker-labs.service /etc/systemd/system/docker-labs.service || { install -m 0644 docker-labs.service /etc/systemd/system/docker-labs.service; changed=1; }
# earlier versions used a host bridge and an nftables table: remove them
if [ -f /etc/systemd/system/lt-labs-firewall.service ]; then
  systemctl disable --now lt-labs-firewall 2>/dev/null || true
  rm -f /etc/systemd/system/lt-labs-firewall.service /etc/docker-labs/lt-labs-firewall.nft
  ip link del lt-default 2>/dev/null || true
fi
systemctl daemon-reload
systemctl enable docker-labs
# a restart stops every running lab: only when the configuration changed (or the daemon is not running)
if [ "$changed" = 1 ] || ! systemctl is-active --quiet docker-labs; then systemctl restart docker-labs; else echo "lab daemon unchanged, not restarted"; fi
for i in $(seq 1 30); do docker -H unix:///run/lt-labs/docker.sock info >/dev/null 2>&1 && break; sleep 1; done
docker -H unix:///run/lt-labs/docker.sock info --format 'lab daemon: {{.ServerVersion}}, {{.SecurityOptions}}'
