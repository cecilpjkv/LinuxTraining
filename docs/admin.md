# Administration & operations

How to install, run and administer a LinuxTraining server from the shell: the administrator account, the backend
commands, updates and backups. For the guided first-time install (from an empty server, with screenshots of each
step) see [INSTALL.md](INSTALL.md); for the architecture and reverse-proxy/HTTPS details see
[deployment.md](deployment.md).

Everything here is run **as root on the server**, from the deploy directory unless noted:

```sh
cd /opt/linuxtraining/deploy
```

---

## 1. What runs where

| Thing | Where |
|---|---|
| Code checkout | `/opt/linuxtraining` (this git repository) |
| Compose project | `/opt/linuxtraining/deploy/docker-compose.yml` (services `db`, `backend`, `web`) |
| Containers | `linuxtraining-db-1`, `linuxtraining-backend-1`, `linuxtraining-web-1` |
| Secrets | `/opt/linuxtraining/deploy/.env` (database password, secret key) — **not** in git |
| Database data | Docker volume `linuxtraining_pgdata` (PostgreSQL) |
| Admin password (first run) | `/root/.lt-admin-password` (mode 0600) |
| Lab images | `linux-training-base`, `-web`, `-lamp`, `-cloud`, `-devops`, `-debian` on the lab Docker daemon |
| Lab Docker daemon | separate, user-namespace-remapped (`/run/lt-labs/docker.sock`); only the backend talks to it |

The application containers run on the host's main Docker daemon; the training labs run on a second, isolated daemon.
Run all `docker compose` commands below from `/opt/linuxtraining/deploy`.

---

## 2. Install on a new server (short form)

AlmaLinux / Rocky / RHEL **9 or 10**, as root, with access to this repository. Full walkthrough: [INSTALL.md](INSTALL.md).

**Before you start, the server needs:**

- **Supported OS**: AlmaLinux / Rocky / RHEL 9 or 10 (the installer refuses anything else). 2 GB RAM minimum, 5 GB and
  2 vCPU recommended; ~20 GB free disk.
- **Outbound internet during the install** — the first run downloads the Docker packages and dnf packages, and the
  lab-image build pulls base images from Docker Hub (`almalinux/9-init`, `alpine`, `php`, `mariadb`, `nginx`,
  `busybox`). Once built, the **running labs have no internet** — only the install host needs it. If builds fail with
  Docker Hub "toomanyrequests" (anonymous pull rate limit), run `docker login` first and re-run the installer, or
  retry later.
- **Access to this (private) repository** — a GitHub **deploy key** on the server, or make the repo public and clone
  over HTTPS. Full steps: [INSTALL.md](INSTALL.md) Step 5.
- **Inbound TCP 80** open to the server (and 443 if you add HTTPS) in any provider firewall / security group.

```sh
dnf -y update                       # reboot if it installed a new kernel, then reconnect
dnf -y install git
git clone git@github.com:cecilpjkv/LinuxTraining.git /opt/linuxtraining
/opt/linuxtraining/deploy/install-almalinux.sh
```

The installer is idempotent — it does everything in one run and is safe to run again:

- installs Docker and the Compose plugin, enables Docker, persists IPv4 forwarding;
- sets up the isolated lab Docker daemon;
- builds the six lab images (first run: **10–20 minutes**, mostly image builds);
- writes `deploy/.env` (generates `LT_DB_PASSWORD` and `LT_SECRET_KEY` if absent);
- starts the application (`docker compose up -d --build`), running database migrations automatically;
- creates the first administrator and prints its password (also saved to `/root/.lt-admin-password`);
- generates the shared technician test password;
- opens the firewall for TCP 80 (unless `LT_OPEN_FIREWALL=0`).

When it finishes it prints the URL, the admin password and the test password. Open `http://SERVER-IP/`.

### Installer options (environment variables)

| Variable | Default | Meaning |
|---|---|---|
| `LT_HTTP_PORT` | `80` | host port the web interface listens on |
| `LT_ADMIN_USER` | `admin` | administrator created on the first run |
| `LT_ADMIN_PASSWORD` | generated | its password (otherwise generated, printed once, saved to `/root/.lt-admin-password`) |
| `LT_TEST_PASSWORD` | generated | shared password technicians type with their name + e-mail (empty = none asked) |
| `LT_SKIP_IMAGES` | — | `LT_SKIP_IMAGES=1` skips rebuilding the lab images (faster re-runs when only the app changed) |
| `LT_OPEN_FIREWALL` | `1` | `0` to not touch firewalld |

Example — pin the admin password and skip image rebuilds on a re-run:

```sh
LT_ADMIN_PASSWORD='choose-a-strong-one' LT_SKIP_IMAGES=1 /opt/linuxtraining/deploy/install-almalinux.sh
```

### Verify it is up

```sh
cd /opt/linuxtraining/deploy
docker compose ps                                   # db, backend, web all "running"/"healthy"
curl -s -o /dev/null -w '%{http_code}\n' http://localhost/        # 200
curl -s http://localhost/api/health                 # {"status":"ok"}
```

---

## 3. Running backend commands

The management CLI and all database/migration commands run **inside the backend container**. The pattern is:

```sh
cd /opt/linuxtraining/deploy
docker compose exec backend <command>
```

Use `exec -T` (no TTY) in scripts/cron; use plain `exec` when a command prompts you (for example for a password).

### The management CLI (`app.cli`)

```sh
docker compose exec backend python -m app.cli --help
```

Two subcommands:

| Command | What it does |
|---|---|
| `create-admin USERNAME [--email E]` | create an administrator, or reset an existing user to admin with a new password |
| `seed` | import scenario packages under `LT_SCENARIOS_DIR` that were never imported |

The password is **never** passed on the command line: the command reads it from the terminal, or from the
`LT_ADMIN_PASSWORD` environment variable.

### Other useful backend commands

```sh
# database migrations (run automatically at every backend start)
docker compose exec backend alembic upgrade head
docker compose exec backend alembic current
docker compose exec backend alembic history

# a database shell (psql)
docker compose exec db psql -U linuxtraining -d linuxtraining

# logs
docker compose logs -f backend          # follow the backend log
docker compose logs --since 1h web

# restart / apply code or .env changes
docker compose up -d                     # recreate only what changed
docker compose restart backend
```

> **One backend only.** The scheduler runs inside the backend process. Do not scale the `backend` service or add
> uvicorn workers.

---

## 4. The administrator account

Administrators sign in from the start page via **Administrator login** (`/admin/login`) with a username and
password. They manage scenarios, review attempts, see the dashboard and manage users. Only administrators have
passwords.

### Create an administrator or reset its password

```sh
cd /opt/linuxtraining/deploy
docker compose exec backend python -m app.cli create-admin admin --email admin@example.com
# → prompts: Password:
```

- If the user does not exist, it is **created** as an administrator.
- If the user already exists, it is **promoted to admin and its password reset** — this is how you reset a forgotten
  admin password.
- Password policy: **at least 10 characters** (max 256). There is no complexity rule; choose a long passphrase.

Non-interactive (e.g. from a script) — pass the password in the environment, never as an argument:

```sh
docker compose exec -T -e LT_ADMIN_PASSWORD='a-long-passphrase' backend \
  python -m app.cli create-admin admin --email admin@example.com
```

After the first install, change the generated password:

```sh
docker compose exec backend python -m app.cli create-admin admin
rm -f /root/.lt-admin-password        # remove the generated one once you have set your own
```

### Manage accounts in the admin UI

Sign in as an administrator → **Users**. From there you can, for each user:

- change the **role** (admin ⇄ technician),
- **enable/disable** the account (`active`),
- edit the **full name**.

Safety guard: you cannot demote or disable **your own** account (keep a second admin if you want to be able to).

### Inspect or fix accounts from the database

When you have no working admin login, use the CLI `create-admin` above to make one. To look at accounts directly:

```sh
# list administrators
docker compose exec db psql -U linuxtraining -d linuxtraining \
  -c "SELECT id, username, email, role, active FROM users WHERE role='admin' ORDER BY id;"

# how many admins exist (the installer uses this)
docker compose exec db psql -U linuxtraining -d linuxtraining -Atc \
  "SELECT count(*) FROM users WHERE role='admin';"

# demote an admin to technician (do not demote your only admin)
docker compose exec db psql -U linuxtraining -d linuxtraining \
  -c "UPDATE users SET role='technician' WHERE username='someadmin';"
```

### Technicians

Technicians do **not** have passwords. On the start page they enter their **name and e-mail address**; the same
e-mail address returns them to their account and their earlier results. Control this with `LT_ALLOW_REGISTRATION`
in `deploy/.env` (`true` by default; `false` turns self-start off). A shared `LT_TEST_PASSWORD`, if set, is the extra
word they must type alongside their name and e-mail to begin.

---

## 5. Scenarios

Scenario packages live in `scenarios/<name>/` (`scenario.yaml`, `setup.sh`, `verify.sh`, `score.yaml`; format in
[scenarios.md](scenarios.md)). They are imported at backend start, **each slug once** — edits made later in the admin
UI are kept, and deleted scenarios stay deleted.

To add or update packages on disk and import them without a full restart:

```sh
cd /opt/linuxtraining/deploy
git -C /opt/linuxtraining pull          # if the packages came from the repository
docker compose exec backend python -m app.cli seed
```

You can also upload a `.zip`/`.tar.gz` or edit scenarios in the admin UI (**Scenarios → Import packages**).

---

## 6. Updating the platform

```sh
cd /opt/linuxtraining
git pull
deploy/install-almalinux.sh             # re-run: updates the app, keeps data, secrets and passwords
```

Re-running the installer keeps the database, `deploy/.env` and existing passwords. Lab images are rebuilt only when
`images/` changed; add `LT_SKIP_IMAGES=1` to skip rebuilding them when you only changed the application:

```sh
LT_SKIP_IMAGES=1 deploy/install-almalinux.sh
```

If you only changed application code and prefer not to run the installer:

```sh
cd /opt/linuxtraining/deploy
docker compose up -d --build            # rebuild + restart backend/web; migrations run on start
```

---

## 7. Backups and restore

The database holds everything worth keeping: users, scenarios (all versions), attempts, command history and scores.
Labs hold nothing worth keeping. **Also keep `deploy/.env`** — without its `LT_SECRET_KEY` and `LT_DB_PASSWORD` a
restore cannot be read.

```sh
cd /opt/linuxtraining/deploy
# back up
docker compose exec -T db pg_dump -U linuxtraining -Fc linuxtraining > /var/backups/linuxtraining-$(date +%F).dump
# restore into the running database
docker compose exec -T db pg_restore -U linuxtraining -d linuxtraining --clean --if-exists \
  < /var/backups/linuxtraining-YYYY-MM-DD.dump
```

Daily job, `/etc/cron.d/linuxtraining-backup` (keeps 14 days):

```
0 3 * * * root cd /opt/linuxtraining/deploy && docker compose exec -T db pg_dump -U linuxtraining -Fc linuxtraining > /var/backups/linuxtraining-$(date +\%F).dump && find /var/backups -name 'linuxtraining-*.dump' -mtime +14 -delete
```

Keep a copy of `deploy/.env` with your backups (store it somewhere safe — it is a secret).

---

## 8. Troubleshooting

| Symptom | Check |
|---|---|
| Web interface does not load | `docker compose ps`; `docker compose logs backend`; is port 80 (or `LT_HTTP_PORT`) open in the provider firewall? |
| `curl http://localhost/api/health` not `ok` | `docker compose logs backend` — usually a database or migration error |
| Lost admin password | `docker compose exec backend python -m app.cli create-admin admin` (resets it) |
| "an administrator exists already" on install | expected; reset with the `create-admin` command above |
| Labs will not start | the lab daemon or images; see the lab/daemon notes in [deployment.md](deployment.md) |
| Disk filling up | prune old layers: `docker image prune -f` and `docker -H unix:///run/lt-labs/docker.sock image prune -f`; build cache: `docker builder prune -f` |
| Login cookie rejected behind HTTPS | set `LT_COOKIE_SECURE=true` in `deploy/.env`, then `docker compose up -d` |

For the reverse proxy, HTTPS and the security model, see [deployment.md](deployment.md) and [security.md](security.md).
