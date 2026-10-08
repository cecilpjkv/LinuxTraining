# Deployment

Target: AlmaLinux 9 (also tested on AlmaLinux 10), 2 vCPU, 5 GB RAM, 50 GB disk. The application runs with Docker
Compose; the training labs run on a **separate** Docker daemon (`docker-labs`) with user-namespace remapping.

```
Browser ──HTTPS──> reverse proxy (host nginx or Caddy, :443)
                     └──> web container (nginx: React app, /api and /ws proxy, 127.0.0.1:8080)
                            └──> backend container (FastAPI, scheduler, Lab Manager) ──> PostgreSQL container
                                     └── /run/docker-labs.sock ──> docker-labs daemon ──> lab containers
                                                                    (internal network, no internet, uid 200000+)
```

## 1. Docker Engine

```sh
dnf -y install dnf-plugins-core
dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
install -d /etc/docker
cat > /etc/docker/daemon.json <<'JSON'
{
  "firewall-backend": "nftables",
  "log-driver": "local",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
JSON
systemctl enable --now docker
```

If `dnf` proposes `kernel-debug-*` packages together with docker-ce, decline them: they are not needed and a newer
debug kernel may become the default boot kernel. The nftables firewall backend (above) avoids the iptables
`xt_addrtype` module; with the iptables backend install `kernel-modules-extra-$(uname -r)`.

## 2. Lab daemon (user-namespace remapped)

```sh
git clone git@github.com:cecilpjkv/LinuxTraining.git /opt/linuxtraining
/opt/linuxtraining/deploy/docker-labs/install.sh
```

This creates the `dockremap` user (subordinate ids 200000-265535), `/etc/docker-labs/daemon.json` and the
`docker-labs.service` unit:

- **user-namespace remapping**: root inside a lab is uid 200000+ on the host;
- **its own network namespace** `ltlabs` (entered with `nsenter --net`, mounts stay shared): every lab gets its own
  internal network inside it, with no route to the host, the internet or another lab. Do not replace this with
  `PrivateNetwork=yes` (a private mount namespace hides the container root filesystems from runc), and do not run
  it in the host namespace (a second dockerd there deletes `docker0`, the main daemon's bridge);
- **no firewall management** (`iptables: false`): the main daemon owns the Docker nftables tables;
- its own address pool (`10.213.0.0/16`) and containerd namespaces.

The application's own containers stay on the normal daemon; the backend only gets the lab daemon's socket.

## 3. Lab images

```sh
/opt/linuxtraining/images/build.sh
```

Builds `linux-training-base`, `-web` and `-lamp` on the main daemon (it can download packages) and loads them into
the lab daemon. Rebuild after changing `images/`; running labs keep the image they started with.

## 4. Application (PostgreSQL, backend, frontend)

Create `/opt/linuxtraining/deploy/.env` (mode 0600):

```sh
cd /opt/linuxtraining/deploy
umask 077
printf 'LT_DB_PASSWORD=%s\nLT_SECRET_KEY=%s\n' "$(openssl rand -hex 24)" "$(openssl rand -hex 32)" > .env
printf 'LT_COOKIE_SECURE=true\nLT_ALLOW_REGISTRATION=true\nLT_HTTP_PORT=127.0.0.1:8080\n' >> .env
docker compose up -d --build
```

| Variable | Meaning |
|---|---|
| `LT_DB_PASSWORD` | PostgreSQL password (also used by the backend) |
| `LT_SECRET_KEY` | signs the session tokens; changing it logs everybody out |
| `LT_COOKIE_SECURE` | `true` once HTTPS is in front (section 5) |
| `LT_ALLOW_REGISTRATION` | technicians start with their name and e-mail address (no password); `false` turns that off |
| `LT_HTTP_PORT` | where the web container listens; `127.0.0.1:8080` behind a reverse proxy |

The backend runs the database migrations (`alembic upgrade head`) and imports new scenario packages at every start.
PostgreSQL data lives in the `linuxtraining_pgdata` volume.

**One backend process only**: the scheduler runs inside it. Do not scale the backend service or add uvicorn workers.

## 5. Reverse proxy and HTTPS

Host nginx in front of the web container; the terminal needs the WebSocket upgrade:

```nginx
map $http_upgrade $connection_upgrade { default upgrade; '' close; }

server {
    listen 443 ssl http2;
    server_name training.example.com;
    ssl_certificate     /etc/letsencrypt/live/training.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/training.example.com/privkey.pem;
    client_max_body_size 2m;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 3600s;
    }
}
server { listen 80; server_name training.example.com; return 301 https://$host$request_uri; }
```

Certificates with Let's Encrypt: `dnf -y install certbot python3-certbot-nginx`, then
`certbot --nginx -d training.example.com`. Alternative: Caddy, whose whole configuration is
`training.example.com { reverse_proxy 127.0.0.1:8080 }` (it obtains certificates by itself).
After HTTPS works, set `LT_COOKIE_SECURE=true` and run `docker compose up -d`.

## 6. Administrator account

```sh
cd /opt/linuxtraining/deploy
docker compose exec backend python -m app.cli create-admin admin --email admin@example.com
```

It asks for the password (or reads `LT_ADMIN_PASSWORD`; never pass it as an argument). The same command resets an
existing administrator's password. Only administrators have passwords: technicians enter their name and e-mail
address on the start page; the same address returns them to their account and earlier results. The administrator
login is linked from the start page (`/admin/login`).

## 7. Scenarios

- Packages in `scenarios/<name>/` (`scenario.yaml`, `setup.sh`, `verify.sh`, `score.yaml`) are imported at backend
  start, each **once**: edits made later in the admin UI are kept, deleted scenarios stay deleted.
- Add a package: copy its directory into `scenarios/` and restart the backend (or use *Scenarios → Import packages*),
  upload a `.zip`/`.tar.gz` in the admin UI, or create it in the scenario editor. Format: `docs/scenarios.md`.

## 8. Database migrations

Automatic at backend start. By hand: `docker compose exec backend alembic upgrade head`; inspect with
`alembic current` and `alembic history` in the same container.

## 9. Backups

Database (users, scenarios with all versions, attempts, command history, scores):

```sh
cd /opt/linuxtraining/deploy
docker compose exec -T db pg_dump -U linuxtraining -Fc linuxtraining > /var/backups/linuxtraining-$(date +%F).dump
```

Restore into the running database:

```sh
docker compose exec -T db pg_restore -U linuxtraining -d linuxtraining --clean --if-exists < /var/backups/linuxtraining-YYYY-MM-DD.dump
```

Also keep `deploy/.env` (secret key and database password). Labs hold nothing worth keeping. A daily job, for example
`/etc/cron.d/linuxtraining-backup`:

```
0 3 * * * root cd /opt/linuxtraining/deploy && docker compose exec -T db pg_dump -U linuxtraining -Fc linuxtraining > /var/backups/linuxtraining-$(date +\%F).dump && find /var/backups -name 'linuxtraining-*.dump' -mtime +14 -delete
```

## 10. Disk and cleanup

- A lab is destroyed when its attempt ends (completed, time limit, abandoned, terminated, idle, lost); every 5 minutes
  the backend also removes lab containers that no running attempt owns.
- Container logs are capped: 10 MB x 3 per application container, 1 MB x 2 per lab.
- Old layers after rebuilding images: `docker image prune -f` and
  `docker -H unix:///run/docker-labs.sock image prune -f`; build cache: `docker builder prune -f`.
