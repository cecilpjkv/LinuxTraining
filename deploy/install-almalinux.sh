#!/bin/bash
# LinuxTraining: one-step installation on AlmaLinux 9 or 10 (also Rocky/RHEL 9-10), as root.
#
#   git clone git@github.com:cecilpjkv/LinuxTraining.git /opt/linuxtraining
#   /opt/linuxtraining/deploy/install-almalinux.sh
#
# Safe to run again: it updates what is there (application, lab images) and keeps data, secrets and the
# administrator's password. Options (environment variables):
#   LT_HTTP_PORT=80            port of the web interface (e.g. 127.0.0.1:8080 behind your own reverse proxy)
#   LT_ADMIN_USER=admin        administrator created on the first run
#   LT_ADMIN_PASSWORD=...      its password (default: generated, printed once, kept in /root/.lt-admin-password)
#   LT_SKIP_IMAGES=1           do not rebuild the lab images (faster re-runs when images/ did not change)
#   LT_OPEN_FIREWALL=0         do not open the web port in firewalld
#   LT_TEST_PASSWORD=...       shared password technicians enter to start (default: generated on the first run;
#                              change it in deploy/.env, then: docker compose up -d)
set -euo pipefail

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die() { printf '\033[31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root"
. /etc/os-release
case "${ID:-} ${ID_LIKE:-}" in *rhel*|*almalinux*|*rocky*|*centos*) ;; *) die "this script is for AlmaLinux/Rocky/RHEL (found ${PRETTY_NAME:-unknown})";; esac
case "${VERSION_ID%%.*}" in 9|10) ;; *) die "AlmaLinux 9 or 10 is required (found $VERSION_ID)";; esac

APP=$(cd "$(dirname "$0")/.." && pwd)
[ -f "$APP/deploy/docker-compose.yml" ] || die "run this script from a checkout of the repository"
PORT=${LT_HTTP_PORT:-80}
ADMIN_USER=${LT_ADMIN_USER:-admin}

say "Base packages"
dnf -y -q install dnf-plugins-core git openssl curl tar >/dev/null

say "Docker Engine"
if ! command -v dockerd >/dev/null; then
  dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo >/dev/null
  # the matching extra modules first, so dnf never pulls a newer debug kernel to satisfy Docker's dependencies
  dnf -y -q install "kernel-modules-extra-$(uname -r)" >/dev/null 2>&1 || true
  dnf -y -q install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
fi
if [ ! -f /etc/docker/daemon.json ]; then
  install -d /etc/docker
  cat > /etc/docker/daemon.json <<'JSON'
{
  "firewall-backend": "nftables",
  "log-driver": "local",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
JSON
fi
# with the nftables firewall backend Docker does not enable IPv4 forwarding itself, and refuses to start without
# it: persist it, or the daemon (and the whole application) fails after the next reboot
cat > /etc/sysctl.d/90-linuxtraining.conf <<'SYSCTL'
# LinuxTraining: Docker (nftables firewall backend) needs IPv4 forwarding and does not enable it itself
net.ipv4.ip_forward = 1
SYSCTL
sysctl -q -p /etc/sysctl.d/90-linuxtraining.conf
systemctl reset-failed docker 2>/dev/null || true
systemctl enable --now docker >/dev/null
for i in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 1; done
docker info >/dev/null 2>&1 || die "the Docker daemon does not start (see journalctl -u docker)"
docker compose version >/dev/null || die "docker compose plugin missing"

say "Lab daemon (user-namespace remapped, own network namespace)"
"$APP/deploy/docker-labs/install.sh"

if [ "${LT_SKIP_IMAGES:-0}" != 1 ]; then
  say "Lab images (base, web, lamp) — the first build takes several minutes"
  "$APP/images/build.sh"
fi

say "Application settings"
cd "$APP/deploy"
if [ ! -f .env ]; then
  umask 077
  {
    echo "LT_DB_PASSWORD=$(openssl rand -hex 24)"
    echo "LT_SECRET_KEY=$(openssl rand -hex 32)"
    echo "LT_HTTP_PORT=$PORT"
    echo "LT_COOKIE_SECURE=false"
    echo "LT_ALLOW_REGISTRATION=true"
  } > .env
  umask 022
  echo "created $APP/deploy/.env (keep it: secret key and database password)"
else
  grep -q '^LT_HTTP_PORT=' .env || echo "LT_HTTP_PORT=$PORT" >> .env
  echo "keeping the existing $APP/deploy/.env"
fi
grep -q '^LT_TEST_PASSWORD=' .env || echo "LT_TEST_PASSWORD=${LT_TEST_PASSWORD:-$(openssl rand -base64 9 | tr -d '/+=' | cut -c1-10)}" >> .env
chmod 600 .env
TEST_PW=$(sed -n 's/^LT_TEST_PASSWORD=//p' .env)

say "Application (PostgreSQL, backend, web) — migrations and scenario import run at start"
docker compose up -d --build --remove-orphans
for i in $(seq 1 90); do docker compose exec -T backend python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/health')" >/dev/null 2>&1 && break; sleep 2; done
docker compose exec -T backend python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/health')" >/dev/null 2>&1 || die "the backend did not become healthy (docker compose logs backend)"

say "Administrator"
has_admin=$(docker compose exec -T db psql -U linuxtraining -d linuxtraining -Atc "SELECT count(*) FROM users WHERE role='admin'" 2>/dev/null || echo 0)
if [ "${has_admin:-0}" -gt 0 ] && [ -z "${LT_ADMIN_PASSWORD:-}" ]; then
  echo "an administrator exists already (reset a password with: docker compose exec backend python -m app.cli create-admin NAME)"
else
  PW=${LT_ADMIN_PASSWORD:-$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-20)}
  docker compose exec -T -e LT_ADMIN_PASSWORD="$PW" backend python -m app.cli create-admin "$ADMIN_USER"
  ( umask 077; echo "$PW" > /root/.lt-admin-password )
  NEW_PW=$PW
fi

if [ "${LT_OPEN_FIREWALL:-1}" = 1 ] && systemctl is-active --quiet firewalld; then
  say "Firewall"
  p=${PORT##*:}
  case "$PORT" in 127.0.0.1:*|localhost:*) echo "port $PORT is local only: nothing to open";;
    *) firewall-cmd -q --permanent --add-port="$p/tcp" && firewall-cmd -q --reload && echo "opened $p/tcp in firewalld";; esac
fi

say "Backups (daily database dump, 14 days kept)"
cat > /etc/cron.d/linuxtraining-backup <<CRON
0 3 * * * root mkdir -p /var/backups/linuxtraining && cd $APP/deploy && docker compose exec -T db pg_dump -U linuxtraining -Fc linuxtraining > /var/backups/linuxtraining/db-\$(date +\%F).dump && find /var/backups/linuxtraining -name 'db-*.dump' -mtime +14 -delete
CRON
echo "/etc/cron.d/linuxtraining-backup -> /var/backups/linuxtraining"

IP=$(hostname -I | awk '{print $1}')
p=${PORT##*:}; [ "$p" = 80 ] && URL="http://$IP/" || URL="http://$IP:$p/"
say "Done"
echo "  Web interface : $URL   (technicians: name + e-mail; administrators: '$ADMIN_USER' via 'Administrator login')"
[ -n "${NEW_PW:-}" ] && echo "  Admin password: $NEW_PW   (also in /root/.lt-admin-password, mode 0600)"
[ -n "$TEST_PW" ] && echo "  Test password : $TEST_PW   (technicians enter it with name + e-mail; set LT_TEST_PASSWORD in $APP/deploy/.env)"
echo "  Scenarios     : $(docker compose exec -T db psql -U linuxtraining -d linuxtraining -Atc 'SELECT count(*) FROM scenarios' 2>/dev/null)"
echo "  Update later  : git -C $APP pull && $0"
echo "  HTTPS, backups and more: $APP/docs/deployment.md"
