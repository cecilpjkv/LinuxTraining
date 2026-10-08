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
- [ ] Phase 2: scenario management, Docker labs, resource weights, concurrency limit
- [ ] Phase 3: browser terminal (WebSocket + PTY), command logging
- [ ] Phase 4: setup/verify scripts, scoring
- [ ] Phase 5: attempt history, admin review, dashboard
- [ ] Phase 6: cleanup, queue, timeouts, security hardening

## Quick start (development host)

    cd deploy
    printf 'LT_DB_PASSWORD=%s\nLT_SECRET_KEY=%s\n' "$(openssl rand -hex 24)" "$(openssl rand -hex 32)" > .env
    docker compose up -d --build
    docker compose exec backend python -m app.cli create-admin admin   # asks for the password
    ../scripts/test.sh                                                 # backend tests (database linuxtraining_test)
