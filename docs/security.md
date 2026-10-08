# Security model

Spec §17, requirement by requirement.

| Requirement | How |
|---|---|
| No Docker socket exposed to the frontend | Only the backend container mounts a Docker socket, and it is the **lab** daemon's (`/run/lt-labs/docker.sock`), not the one running the application. The browser talks to `/api` and `/ws` only. |
| Containers run with resource limits | Per lab: CPU (`lab_cpu`), memory without swap (`lab_memory_mb`), PIDs (`lab_pids_limit`), `nofile` 65536, logs 1 MB x 2. Admin-configurable. |
| Scenario scripts execute only inside containers | `setup.sh` and `verify.sh` are streamed to `bash -s` over `docker exec` stdin; the backend never runs them, and no copy is left in the lab for the technician to read. |
| Validate uploaded scenario files | Size limits, YAML parsing, closed lists (categories, difficulties, extra capabilities), image names restricted to `linux-training-*`, tmpfs paths from an allow-list, score names and regexes checked. |
| Prevent path traversal | Packages: only the four known files are read; absolute paths, `..`, backslashes, links, devices and deep paths are refused before any normalisation. Package directories must match `[a-z0-9-]` and stay under the scenarios root. |
| Prevent arbitrary host command execution | No API runs anything on the host; the only execution path is `docker exec` into a lab. |
| Authentication for all admin APIs | Every `/api/admin/*` route depends on `require_admin`; tests check technicians get 403. |
| Technician can access only their own lab | Attempt APIs return 404 for other users' attempts; the terminal WebSocket checks the session cookie, ownership, status `ready` and the Origin. |
| Admin APIs require admin role | As above; the technician start page (name + e-mail) only ever creates technicians and refuses administrators' addresses. |
| No host filesystem in containers | No bind mounts or volumes into labs; only tmpfs (`/run`, `/run/lock`, scenario tmpfs from an allow-list). |
| Restricted networking | The lab daemon runs in its own network namespace; every lab has its own internal network there: no internet, no host, no other lab. |
| Non-privileged containers | Never `--privileged`. Labs add only `CAP_SYS_ADMIN` (systemd needs its own cgroup tree, in a private cgroup namespace) plus capabilities a scenario declares from a short allow-list (`NET_ADMIN`, …). The technician's shell runs with `CAP_SYS_ADMIN` and other dangerous capabilities removed from its bounding set. |
| — and if a lab is escaped anyway | User-namespace remapping: root in a lab is an unprivileged uid (200000+) on the host. |
| Timeout and PID limits | Per-scenario time limit capped by `max_test_minutes` (graded at the deadline), idle labs abandoned, PID limit per lab, script timeouts (`timeout -k`). |

Application:

- Technicians have no password: they are identified by the e-mail address they enter (owner's decision for this
  internal training), so anyone who types a technician's address sees that technician's attempts. Administrators
  log in with a password.
- Passwords: scrypt (n=2^14, r=8, p=1, 16-byte salt); policy minimum 10 characters; constant-time comparison; a
  missing user costs the same time as a wrong password.
- Sessions: HS256 JWT in an `HttpOnly`, `SameSite=Strict` cookie (`Secure` with `LT_COOKIE_SECURE=true`).
- Login brake: 10 failures per username or client address in 15 minutes → HTTP 429.
- Headers (web container): `Content-Security-Policy`, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`,
  `Referrer-Policy: same-origin`.
- Tests run only against a database whose name ends in `_test`.

Residual risks, accepted for V1:

- A technician is root in the lab and can tamper with its tools (for example replace `curl`) to influence
  `verify.sh`. The command history shows such tampering; verification uses absolute `PATH` and helper functions
  that are not stored in the lab.
- Root in the lab can ask systemd (which keeps `CAP_SYS_ADMIN`) to run commands; user-namespace remapping limits what
  that can reach on the host.
- The backend holds the lab daemon's socket: a backend compromise controls the labs (not the application's own
  containers or the host's Docker daemon).
