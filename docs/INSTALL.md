# Installing LinuxTraining — step by step

This guide installs the whole platform on a new server. Follow the steps in order; each step says what you should
see. It takes about 20-30 minutes, most of it waiting.

---

## Step 1 — Get a server

You need a Linux server (virtual or physical) with:

| | Minimum | Recommended |
|---|---|---|
| Operating system | **AlmaLinux 9 or 10** (Rocky Linux and RHEL 9/10 also work) | AlmaLinux 9 |
| CPU | 1 vCPU | 2 vCPU |
| Memory | 2 GB | 5 GB |
| Disk | 20 GB | 50 GB |
| Network | a public or internal IP address | |

Other Linux distributions (Ubuntu, Debian, ...) are **not** supported by the installer.

From your hosting provider you get: the server's **IP address** (for example `203.0.113.25`) and the **root password**
(or an SSH key).

> If your provider has a firewall / "security group" in its control panel, allow incoming **TCP 22** (SSH) and
> **TCP 80** (web) to the server.

---

## Step 2 — Connect to the server

On **Windows**: open *PowerShell* (or *Windows Terminal*). On **macOS / Linux**: open *Terminal*. Type (use your
server's IP address):

```sh
ssh root@203.0.113.25
```

- The first time it asks `Are you sure you want to continue connecting (yes/no)?` — type `yes` and press Enter.
- Type the root password (nothing appears while you type — that is normal) and press Enter.

You are in when you see a prompt like:

```
[root@yourserver ~]#
```

All following commands are typed at this prompt. (Copy a command, paste it with right-click or Ctrl+Shift+V, press
Enter.)

---

## Step 3 — Update the server

```sh
dnf -y update
```

This can take a few minutes. If it installed a new kernel, restart and reconnect:

```sh
reboot
```

Wait one minute, then connect again as in step 2.

---

## Step 4 — Install git

```sh
dnf -y install git
```

You should see `Complete!`.

---

## Step 5 — Give the server access to the code on GitHub

The repository `cecilpjkv/LinuxTraining` is **private**, so the server needs permission to download it. The safest
way is a *deploy key* (read-only access to this one repository).

**5a.** Create a key on the server (press Enter at every question):

```sh
ssh-keygen -t ed25519 -C "linuxtraining-server" -f /root/.ssh/linuxtraining_deploy
```

**5b.** Show the public key:

```sh
cat /root/.ssh/linuxtraining_deploy.pub
```

It prints one line starting with `ssh-ed25519 ...`. Select and copy the whole line.

**5c.** In your web browser, open
**https://github.com/cecilpjkv/LinuxTraining/settings/keys** → **Add deploy key**:

- *Title*: the server's name, e.g. `training-server-1`
- *Key*: paste the line from 5b
- leave *Allow write access* **unticked**
- click **Add key**

**5d.** Tell the server to use this key for GitHub:

```sh
cat >> /root/.ssh/config <<'EOF'
Host github.com
    IdentityFile /root/.ssh/linuxtraining_deploy
    IdentitiesOnly yes
EOF
chmod 600 /root/.ssh/config
```

**5e.** Test it:

```sh
ssh -T git@github.com
```

Type `yes` if asked. You should see: `Hi cecilpjkv/LinuxTraining! You've successfully authenticated...`

> Alternative without a key: make the repository public on GitHub (Settings → General → Danger Zone → Change
> visibility) and use `https://github.com/cecilpjkv/LinuxTraining.git` in step 6.

---

## Step 6 — Download the code

```sh
git clone git@github.com:cecilpjkv/LinuxTraining.git /opt/linuxtraining
```

You should see `Receiving objects: 100% ... done.`

---

## Step 7 — Run the installer

```sh
/opt/linuxtraining/deploy/install-almalinux.sh
```

It installs everything (Docker, the training-lab engine, the lab images, the database, the web application) and
prints progress lines starting with `==>`. **The first run takes 10-20 minutes** — mostly building the lab images.
Do not close the window.

At the end you see something like:

```
==> Done
  Web interface : http://203.0.113.25/   (technicians: name + e-mail; administrators: 'admin' via 'Administrator login')
  Admin password: Xy7pQ2...              (also in /root/.lt-admin-password, mode 0600)
  Scenarios     : 100
```

**Write down the admin password** (or look it up later with `cat /root/.lt-admin-password`).

> Want a different web port, e.g. 8080? Run instead:
> `LT_HTTP_PORT=8080 /opt/linuxtraining/deploy/install-almalinux.sh`

---

## Step 8 — Open the platform

In your web browser go to the address from step 7, for example **http://203.0.113.25/**

- **Technicians**: enter full name and e-mail address → *Continue* → choose a scenario → *Start test*.
- **Administrator**: click **Administrator login** (under the form) → user `admin` + the password from step 7.

Check as administrator: *Dashboard* shows **Scenarios: 100**.

---

## Step 9 — Change the administrator password (recommended)

```sh
cd /opt/linuxtraining/deploy
docker compose exec backend python -m app.cli create-admin admin
```

Type the new password (at least 10 characters) when asked, then remove the old note:

```sh
rm -f /root/.lt-admin-password
```

---

## Done 🎉

---

# Everyday tasks

### Update to the newest version

```sh
cd /opt/linuxtraining
git pull
./deploy/install-almalinux.sh
```

Data, scenarios edited in the admin pages, technicians and passwords are kept. (Add `LT_SKIP_IMAGES=1` in front of
the installer to skip rebuilding the lab images when only the application changed.)

### Backups

The installer schedules a database backup every night at 03:00 into `/var/backups/linuxtraining/` (kept 14 days).
Make one now:

```sh
cd /opt/linuxtraining/deploy
mkdir -p /var/backups/linuxtraining
docker compose exec -T db pg_dump -U linuxtraining -Fc linuxtraining > /var/backups/linuxtraining/db-manual.dump
```

Also keep a copy of `/opt/linuxtraining/deploy/.env` somewhere safe (it holds the database password and the session
key).

### Restore a backup

```sh
cd /opt/linuxtraining/deploy
docker compose exec -T db pg_restore -U linuxtraining -d linuxtraining --clean --if-exists < /var/backups/linuxtraining/db-YYYY-MM-DD.dump
docker compose restart backend
```

### Move to a new server

1. On the old server: make a backup (above) and copy it plus `deploy/.env` to your PC (`scp root@OLD-IP:/var/backups/linuxtraining/db-manual.dump .`).
2. On the new server: steps 1-6, then copy the old `.env` to `/opt/linuxtraining/deploy/.env`, then step 7.
3. Restore the backup (above).

### Check that everything runs

```sh
cd /opt/linuxtraining/deploy
docker compose ps                         # db, backend and web should be "Up"
systemctl is-active docker docker-labs    # both "active"
curl -s http://127.0.0.1/api/health       # {"status":"ok"}
```

### Turn off self-service for technicians

To allow only accounts the administrator creates: edit `/opt/linuxtraining/deploy/.env`, set
`LT_ALLOW_REGISTRATION=false`, then `cd /opt/linuxtraining/deploy && docker compose up -d`.

---

# Optional: HTTPS with your own domain name

1. At your domain provider, create a DNS **A record**, e.g. `training.example.com` → the server's IP. Wait until
   `ping training.example.com` shows that IP.
2. Run the installer with the web port moved to the inside:
   `LT_HTTP_PORT=127.0.0.1:8080 /opt/linuxtraining/deploy/install-almalinux.sh`
   (if you installed before: also change `LT_HTTP_PORT` in `deploy/.env` to `127.0.0.1:8080`, then
   `cd /opt/linuxtraining/deploy && docker compose up -d`)
3. Install Caddy, which gets and renews certificates by itself:
   ```sh
   dnf -y install 'dnf-command(copr)' && dnf -y copr enable @caddy/caddy && dnf -y install caddy
   echo 'training.example.com {
       reverse_proxy 127.0.0.1:8080
   }' > /etc/caddy/Caddyfile
   systemctl enable --now caddy
   firewall-cmd --permanent --add-service=https --add-service=http 2>/dev/null; firewall-cmd --reload 2>/dev/null
   ```
4. In `deploy/.env` set `LT_COOKIE_SECURE=true`, then `cd /opt/linuxtraining/deploy && docker compose up -d`.
5. Open **https://training.example.com/**.

(nginx instead of Caddy: see `docs/deployment.md`, section 5.)

---

# Troubleshooting

| Problem | What to do |
|---|---|
| `Permission denied (publickey)` at step 5e/6 | The deploy key was not added on GitHub, or step 5d was skipped. Repeat 5b-5e. |
| The browser cannot open the page | Check the provider's firewall allows TCP 80; on the server: `docker compose -f /opt/linuxtraining/deploy/docker-compose.yml ps`. |
| `ERROR: ...` from the installer | Read the line; run the installer again (it continues where it stopped). Logs: `journalctl -u docker -u docker-labs -n 50`. |
| A test stays at "Preparing lab" | `cd /opt/linuxtraining/deploy && docker compose logs --tail 50 backend`; check `systemctl status docker-labs`. |
| Forgot the admin password | Step 9 sets a new one. |
| Disk filling up | `docker image prune -f; docker -H unix:///run/lt-labs/docker.sock image prune -f; docker builder prune -f` |

More detail (architecture, security, writing scenarios): `docs/deployment.md`, `docs/security.md`,
`docs/scenarios.md`.
