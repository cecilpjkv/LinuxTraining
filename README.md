# LinuxTraining

Browser-based Linux system-engineer training and assessment platform: technicians fix intentionally broken servers
(isolated Docker labs) in a browser terminal; verification scripts grade the final server state.

Stack: FastAPI + SQLAlchemy + PostgreSQL (backend), React + Vite + xterm.js (frontend), Docker Engine (labs),
Docker Compose (the application itself).

## Layout

| Path | What |
|---|---|
| `backend/` | FastAPI app (`app/`), Alembic migrations, tests |
| `frontend/` | React + Vite app, served by nginx (which also proxies `/api` and `/ws`) |
| `scenarios/` | scenario packages: `scenario.yaml`, `setup.sh`, `verify.sh`, `score.yaml` |
| `images/` | Dockerfiles of the training lab images |
| `deploy/` | Docker Compose deployment |
| `scripts/` | `sync.sh` (copy the tree to the runtime host), `test.sh` (backend tests) |

## Status

- [x] Phase 1: structure, database (9 tables, Alembic), authentication (scrypt + JWT HttpOnly cookie), roles
- [x] Phase 2: scenario management, Docker labs, resource weights, concurrency limit
- [x] Phase 3: browser terminal (WebSocket + PTY), command logging
- [x] Phase 4: setup/verify scripts, scoring (MVP flow verified end to end: scripts/e2e_mvp.py)
- [x] Phase 5: attempt history, admin review, dashboard
- [x] Phase 6: cleanup, queue, timeouts, security hardening (docs/security.md)
- [x] 100 seeded scenarios: the 50 of spec 25 plus 50 more (system/security, web/TLS; easy to extra hard)
- [x] 50 seeded scenarios (spec 25): 15 easy / 25 intermediate / 10 advanced, each proven in a real lab by
      `scripts/check-scenarios.sh` (setup breaks it, the reference fix scores full marks)

## Documentation

- `docs/INSTALL.md`: step-by-step installation on a new server (start here)
- `docs/deployment.md`: installation details (Docker, lab daemon, images, Compose, reverse proxy, HTTPS, admin, backups)
- `docs/scenarios.md`: writing scenarios (format, verify helpers, scoring, pitfalls)
- `docs/security.md`: the security model

## Install on a server (AlmaLinux 9/10)

**Step-by-step guide for any server: [docs/INSTALL.md](docs/INSTALL.md)** (from an empty server to a running
platform, plus updates, backups, HTTPS and troubleshooting).

The short version, as root on AlmaLinux / Rocky / RHEL 9 or 10 with access to this repository:

    dnf -y install git
    git clone git@github.com:cecilpjkv/LinuxTraining.git /opt/linuxtraining
    /opt/linuxtraining/deploy/install-almalinux.sh

Then open `http://SERVER-IP/` — technicians enter their name and e-mail; the administrator uses
*Administrator login* (user `admin`, password printed by the installer and kept in `/root/.lt-admin-password`).
Update later with `git -C /opt/linuxtraining pull && /opt/linuxtraining/deploy/install-almalinux.sh`.

## Quick start (development host)

    cd deploy
    printf 'LT_DB_PASSWORD=%s\nLT_SECRET_KEY=%s\n' "$(openssl rand -hex 24)" "$(openssl rand -hex 32)" > .env
    docker compose up -d --build
    docker compose exec backend python -m app.cli create-admin admin   # asks for the password
    ../scripts/test.sh                                                 # backend tests (database linuxtraining_test)
