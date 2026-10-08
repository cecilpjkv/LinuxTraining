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
- [x] 50 seeded scenarios (spec 25): 15 easy / 25 intermediate / 10 advanced, each proven in a real lab by
      `scripts/check-scenarios.sh` (setup breaks it, the reference fix scores full marks)

## Documentation

- `docs/deployment.md`: installation (Docker, lab daemon, images, Compose, reverse proxy, HTTPS, admin, backups)
- `docs/scenarios.md`: writing scenarios (format, verify helpers, scoring, pitfalls)
- `docs/security.md`: the security model

## Quick start (development host)

    cd deploy
    printf 'LT_DB_PASSWORD=%s\nLT_SECRET_KEY=%s\n' "$(openssl rand -hex 24)" "$(openssl rand -hex 32)" > .env
    docker compose up -d --build
    docker compose exec backend python -m app.cli create-admin admin   # asks for the password
    ../scripts/test.sh                                                 # backend tests (database linuxtraining_test)
