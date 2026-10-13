# Writing scenarios

A scenario is a directory under `scenarios/` (its name is the identifier: lowercase letters, digits, `-`):

```
scenarios/nginx-config-syntax/
  scenario.yaml   what the technician sees, which lab, limits, options
  setup.sh        breaks the server (runs as root inside the lab, before the technician gets the terminal)
  verify.sh       checks the final state (runs as root inside the lab when the test ends)
  score.yaml      points per check, process points, deductions, pass mark
  solution.sh     optional reference fix: never imported or shown; used by scripts/check-scenarios.sh
```

Packages are imported once at backend start (or *Scenarios → Import packages*); they can also be uploaded as
`.zip`/`.tar.gz` or written in the admin editor. Every change to the scripts, scoring or options creates a new
version; attempts keep the version they ran.

## scenario.yaml

```yaml
name: Website down after a configuration change
description: |
  The customer's symptom, never the cause. ("The site returns 502", not "the socket is wrong".)
category: Nginx            # Linux, SSH, Networking, Nginx, Apache, PHP, PHP-FPM, MariaDB, Docker, Git, Ansible, ...
difficulty: easy           # easy | intermediate | advanced | extra-hard (often several faults together)
docker_image: linux-training-web   # linux-training-base | -web (nginx, httpd, php-fpm) | -lamp (+ MariaDB)
                                   # | -devops (git, Ansible, docker/compose via Podman, rsync)
time_limit: 20             # minutes (capped by the admin's maximum test duration)
resource_weight: 2         # 1 basic, 2 web/PHP/networking/Docker, 3 app + database or two servers, 4 heavy (alone)
capabilities: [NET_ADMIN]  # optional: NET_ADMIN, NET_RAW, SYS_PTRACE, SYS_NICE, SYS_RESOURCE
tmpfs:                     # optional small filesystems (disk scenarios), under /srv, /data, /var/www, /var/log/app, ...
  /srv/data: 64                        # 64 MB
  /srv/spool: {size: 64, inodes: 2000} # with an inode limit
collect:                   # optional: commands whose output is kept as the attempt's "final state"
  - nginx -t
nodes:                     # optional: several servers (2-3), see below
  - {name: lb, image: linux-training-web}     # the first one's image is docker_image
  - {name: app1, image: linux-training-web}
nested_containers: true    # optional: the lab runs containers itself (see below)
```

## setup.sh

Runs once, as root, inside the fresh lab, fed to `bash` on standard input (no copy stays in the lab). It must exit 0.
After it, the platform runs `verify.sh`: **at least one scored check must fail**, otherwise the attempt is not
started ("the problem is not in place"). Make the break realistic: build the working state first, then break it the
way a person or a bad change would, and leave realistic logs.

## verify.sh

Also fed on standard input, with helper functions the technician cannot change (they are not stored in the lab):

| Helper | Meaning |
|---|---|
| `check NAME CMD...` | PASS if `CMD` succeeds, FAIL with its output otherwise |
| `pass NAME [detail]` / `fail NAME [detail]` | report a check |
| `partial NAME FRACTION [detail]` | 0..1 of the item's points (only if the item has `partial: true`) |
| `deduct NAME [detail]` | apply a deduction from `score.yaml` |
| `http_code [curl args] URL` | prints the HTTP status |

Check the **state**, not the method: accept every valid fix (moving files or changing the config, raising a limit in
either place, ...). A check that is reported twice keeps the worse result; a check that is never reported scores 0.

## score.yaml

```yaml
pass_score: 70            # percent of the maximum
items:                    # state checks reported by verify.sh
  nginx_running: {points: 25, label: "Nginx is running"}
  site_works: {points: 35, label: "The site answers", partial: true}
process:                  # optional: regular expressions matched against the command history
  read_logs: {points: 5, label: "Read the logs", any_of: ['journalctl', '/var/log/nginx']}
deductions:               # optional: applied when verify.sh calls deduct NAME
  site_removed: {points: 40, label: "The site was removed instead of repaired"}
```

Short form: `nginx_running: 25`. Process points are a small signal on top; the score is decided by the final state.

## Pitfalls (each found by the scenario checker)

- **Standard input**: setup/verify arrive on stdin, so any command that reads stdin swallows the rest of the
  script. Use `ssh -n`, `mysql ... </dev/null`, `cmd </dev/null`.
- **Graceful reloads**: after `systemctl reload nginx/httpd` the old workers answer for a moment; PHP's opcache
  re-reads changed files only every 2 seconds. Web verifies start with `sleep 1` (PHP: `sleep 3`).
- **`top -b`**: filter process lines (`$1 ~ /^[0-9]+$/`), or the summary lines match numeric tests.
- **`/proc/PID/exe`** of another user's process is unreadable without `CAP_SYS_PTRACE`: look at command lines.
- **AlmaLinux images**: `sha256sum`, `yes`, ... are wrappers around the multi-call `coreutils` binary (a copy runs
  as coreutils); `/etc/ssh/sshd_config.d/NN-permitrootlogin.conf` sets `PermitRootLogin yes` and wins over later
  files (sshd takes the first value).
- **nginx default server**: without `default_server` the first server block for the port is the default.
- **Docker-managed files**: `/etc/hosts` and `/etc/resolv.conf` are bind mounts: `sed -i` (rename) fails; write them
  in place (`printf ... > /etc/resolv.conf`, `cat new > /etc/hosts`).
- **Network namespaces**: inside a lab use `nsenter --net=/run/netns/NAME`; `ip netns exec` and `ip -n` remount
  `/sys`, which a user-namespaced lab may not do. The technician's shell has no `CAP_SYS_ADMIN`: anything that needs
  it (for example the `test-from-network` helper) must run through a systemd unit.
- **tmpfs**: the mount point is world-writable (1777) unless `setup.sh` changes it (logrotate refuses such
  directories); inode accounting varies, so fill a volume until it refuses rather than counting.
- **Offline labs**: there is no internet. Packages a scenario wants installed must be in the image's local
  repository (`images/web`: `/opt/training-repo`; `images/devops`: nginx for playbooks).
- **Ansible** needs a UTF-8 locale: verify runs with `LC_ALL=C`, so `export LC_ALL=C.UTF-8 LANG=C.UTF-8 HOME=/root`
  before calling it.
- **sshd is already running** in the images: after changing its configuration in setup, `systemctl restart sshd`
  (`enable --now` does not reload it).
- **Git as root on another user's repository** refuses ("dubious ownership"): `git -c safe.directory='*' ...`.
- **nftables in a lab** (`capabilities: [NET_ADMIN]`): replace your own table (`table inet filter` / `delete table
  inet filter` / `table inet filter {...}`), never `flush ruleset`.

## Several servers (`nodes`)

A lab can have 2-3 servers on one private network (no internet, no other lab). Each server's hostname is its node
name, and the others reach it by that name (`curl http://app1/`, `ssh backup`). The technician's terminal opens on
the first server and has a tab per server; the command history records which server each command ran on.

- `setup.sh`, `verify.sh` and `solution.sh` run on **every** server, with `LT_NODE` (this server) and `LT_NODES`
  (all of them) set: branch on `$LT_NODE`. Setup runs the other servers first and the first server last, so its
  setup can rely on the rest; verify runs in the listed order (a check on a later server can see what an earlier
  one did, for example a test message sent from web01 and looked for on the log server).
- A server's setup can hand a value to the servers set up after it: print a line `@@LT SHARE NAME VALUE` (VALUE
  without spaces: base64 it) and the later setups get `$LT_SHARE_NAME`. Use it for keys made in the lab (never
  commit keys): the server that trusts a key makes the pair, keeps the public half and shares the private one.
- Checks may be reported on any server; a check reported on several keeps the worse result. `collect` commands run
  on every server.
- Every server counts against the lab limits (CPU, memory, PIDs per server): `resource_weight` is at least the number
  of servers. Prove multi-server packages one at a time: `LT_CHECK_WORKERS=1 scripts/check-scenarios.sh NAME`.

## Containers inside a lab (`nested_containers`)

With `nested_containers: true` (and `docker_image: linux-training-devops`) the technician uses `docker` and
`docker compose` as on a Docker host. Behind them is Podman's system service (`podman.socket`, `/run/docker.sock`
points at it); the lab gets `NET_ADMIN` and a writable `/proc/sys` for the engine's networks (see security.md).
There is no registry: setup loads the images from `/opt/lt-images` (`podman load -i /opt/lt-images/nginx.tar`;
`busybox.tar` too) and scenarios refer to them by their full names (`docker.io/library/nginx:1.27-alpine`).
Storage is `vfs` (copies per layer): keep to small images. `podman` in the technician's shell talks to the same
service (`CONTAINER_HOST`); in setup/verify use `docker` or plain `podman`.

## Proving a scenario

```sh
scripts/check-scenarios.sh nginx-        # on the Docker host; every package with a solution.sh by default
```

For each package: setup succeeds and breaks something, the reference fix succeeds, and `verify.sh` then reports every
scored check PASS with no deduction. `scripts/probe_scenario.py SLUG [VERIFY] [commands...]` sets up a lab and runs
commands in it (for debugging).
