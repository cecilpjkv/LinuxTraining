"""End-to-end check of the first deliverable (spec §24) against a running deployment, as a browser would:
admin creates a scenario -> technician starts the nginx scenario -> lab + setup -> terminal over WebSocket ->
commands recorded -> complete -> verify -> score -> lab destroyed.
    python scripts/e2e_mvp.py BASE_URL ADMIN_PASSWORD      (inside the dev image on the compose network)"""
import asyncio
import json
import secrets
import sys
import time

import httpx
import websockets

BASE, ADMIN_PW = sys.argv[1].rstrip("/"), sys.argv[2]


def ok(cond, what):
    print(("ok   " if cond else "FAIL ") + what)
    if not cond:
        sys.exit(1)


def main():
    admin = httpx.Client(base_url=BASE, timeout=30)
    ok(admin.post("/api/auth/login", json={"username": "admin", "password": ADMIN_PW}).status_code == 200, "admin login")
    slug = "e2e-cron-" + secrets.token_hex(3)
    r = admin.post("/api/admin/scenarios", json={
        "slug": slug, "name": "E2E: scheduled jobs stopped", "description": "Nightly jobs did not run.",
        "category": "Linux", "difficulty": "easy", "docker_image": "linux-training-base", "time_limit": 10,
        "resource_weight": 1, "setup_script": "systemctl disable --now crond\n",
        "verify_script": "check crond_running systemctl is-active --quiet crond\n",
        "score_yaml": "items:\n  crond_running: 100\n", "options": {}})
    ok(r.status_code == 201 and r.json()["version"] == 1, "admin created a scenario without code changes")
    sc = next(s for s in admin.get("/api/admin/scenarios").json() if s["slug"] == "nginx-config-syntax")

    tech = httpx.Client(base_url=BASE, timeout=30)
    user = "tech" + secrets.token_hex(3)
    ok(tech.post("/api/auth/register", json={"username": user, "password": "e2e-password-1"}).status_code == 201, "technician registered")
    ok(any(s["id"] == sc["id"] for s in tech.get("/api/scenarios").json()), "technician sees the scenario")
    a = tech.post("/api/attempts", json={"scenario_id": sc["id"]}).json()
    t0 = time.time()
    while a["status"] in ("queued", "provisioning") and time.time() - t0 < 180:
        time.sleep(2)
        a = tech.get(f"/api/attempts/{a['id']}").json()
    ok(a["status"] == "ready", f"lab ready in {time.time() - t0:.0f}s (container created, setup.sh ran, break confirmed)")
    labs = admin.get("/api/admin/labs").json()
    ok(labs["active"] == 1 and labs["weight"] == sc["resource_weight"], f"admin sees the active lab ({labs['active']}/{labs['max_active']}, weight {labs['weight']}/{labs['max_weight']})")

    async def terminal():
        url = BASE.replace("http", "ws") + f"/ws/attempts/{a['id']}/terminal?cols=120&rows=30"
        host = BASE.split("://", 1)[1]
        cookie = "; ".join(f"{k}={v}" for k, v in tech.cookies.items())
        async with websockets.connect(url, additional_headers={"Cookie": cookie, "Origin": f"http://{host}"}) as ws:
            screen = ""
            async def drain(sec):
                nonlocal screen
                end = time.time() + sec
                while time.time() < end:
                    try:
                        screen += await asyncio.wait_for(ws.recv(), timeout=max(0.1, end - time.time()))
                    except asyncio.TimeoutError:
                        break
            await drain(2)
            for cmd in ["systemctl status nginx --no-pager | head -5", "nginx -t",
                        "sed -i 's|add_header X-Shop-Version \"2.4\"$|add_header X-Shop-Version \"2.4\";|' /etc/nginx/conf.d/shop.conf",
                        "nginx -t && systemctl restart nginx", "curl -s -H 'Host: shop.example.test' 127.0.0.1 | grep -o 'Shop OK'"]:
                await ws.send(json.dumps({"type": "input", "data": cmd + "\r"}))
                await drain(2.5)
            return screen
    screen = asyncio.run(terminal())
    ok("[root@training" in screen, "browser terminal shows the lab prompt [root@training ~]#")
    ok("Shop OK" in screen and "777;lt" not in screen, "commands ran interactively; no hook markers on screen")
    # someone else's attempt is not reachable
    other = httpx.Client(base_url=BASE, timeout=30)
    other.post("/api/auth/register", json={"username": "x" + user, "password": "e2e-password-1"})
    ok(other.get(f"/api/attempts/{a['id']}").status_code == 404, "another technician cannot see the attempt")

    ok(tech.post(f"/api/attempts/{a['id']}/complete").status_code == 200, "Complete Test accepted")
    t0 = time.time()
    while time.time() - t0 < 180:
        res = tech.get(f"/api/attempts/{a['id']}/result").json()
        if res["status"] not in ("verifying", "ready"):
            break
        time.sleep(2)
    ok(res["status"] == "completed", f"graded in {time.time() - t0:.0f}s")
    ok(res["passed"] and res["percent"] == 100, f"score {res['score']}/{res['max_score']} ({res['percent']}%)")
    print("     " + "; ".join(f"{b['label']}: {b['points']}/{b['max']}" for b in res["breakdown"]))
    review = admin.get(f"/api/admin/attempts/{a['id']}").json()
    ok(review["status"] == "completed" and review["technician"]["username"] == user, "admin can open the attempt review")
    cmds = [(c["command"], c["exit_code"], c["output"]) for c in review["commands"]]
    ok(len(cmds) == 5 and cmds[1][1] == 1 and "add_header" in cmds[1][2], "command history: 5 commands, nginx -t failed with the error shown")
    ok(cmds[4][1] == 0 and cmds[4][2] == "Shop OK", "the recorded output of the last command is the shop page (not the screen echo)")
    ok(all(v["passed"] for v in review["verification"]) and len(review["verification"]) == 4, "4 verification checks PASS")
    ok("syntax is ok" in review["final_state"], "final state collected (nginx -t, status, config)")
    labs = admin.get("/api/admin/labs").json()
    ok(labs["active"] == 0, "lab slot freed")
    sid = next(s["id"] for s in admin.get("/api/admin/scenarios").json() if s["slug"] == slug)
    ok(admin.delete(f"/api/admin/scenarios/{sid}").status_code == 204, "test scenario removed again")
    return a["id"]


if __name__ == "__main__":
    print("attempt", main())
