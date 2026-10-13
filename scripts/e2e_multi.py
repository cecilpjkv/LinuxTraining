import os
"""End-to-end check of a multi-server lab against a running deployment, as a browser would: a technician starts the
two-server load balancer scenario (lb + app1) -> both servers set up -> a terminal tab per server over WebSocket ->
the fix typed on each -> complete -> verify on both -> 100% -> the review shows which server each command ran on.
    python scripts/e2e_multi.py BASE_URL ADMIN_PASSWORD      (inside the dev image on the compose network)"""
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


async def typing(tech, aid, node, cmds):
    url = BASE.replace("http", "ws") + f"/ws/attempts/{aid}/terminal?cols=160&rows=30&node={node}"
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
        for c in cmds:
            await ws.send(json.dumps({"type": "input", "data": c + "\r"}))
            await drain(3)
        return screen


def main():
    admin = httpx.Client(base_url=BASE, timeout=30)
    ok(admin.post("/api/auth/login", json={"username": "admin", "password": ADMIN_PW}).status_code == 200, "admin login")
    sc = next(s for s in admin.get("/api/admin/scenarios").json() if s["slug"] == "net-lb-backend")
    tech = httpx.Client(base_url=BASE, timeout=30)
    user = "tech" + secrets.token_hex(3)
    ok(tech.post("/api/auth/technician", json={"full_name": "E2E Multi", "email": f"{user}@example.test",
                                               "password": os.environ.get("LT_TEST_PASSWORD", "")}).status_code == 200, "technician in")
    a = tech.post("/api/attempts", json={"scenario_id": sc["id"]}).json()
    ok(a["nodes"] == ["lb", "app1"], "the attempt lists its two servers (terminal tabs)")
    t0 = time.time()
    while a["status"] in ("queued", "provisioning") and time.time() - t0 < 300:
        time.sleep(2)
        a = tech.get(f"/api/attempts/{a['id']}").json()
    ok(a["status"] == "ready", f"both servers ready in {time.time() - t0:.0f}s (setup on each, break confirmed)")
    s_app = asyncio.run(typing(tech, a["id"], "app1", [
        "hostname",
        "sed -i 's/listen 127.0.0.1:8080;/listen 8080;/' /etc/nginx/conf.d/shop-backend.conf",
        "sed -i \"s/        tcp dport 22 accept/        tcp dport 22 accept\\n        ip saddr $(getent hosts lb | awk '{print $1}') tcp dport 8080 accept/\" /etc/sysconfig/nftables.conf",
        "systemctl restart nftables nginx && echo app1-fixed"]))
    ok("[root@app1" in s_app and "app1-fixed" in s_app, "the app1 tab is a shell on app1; the fix ran there")
    s_lb = asyncio.run(typing(tech, a["id"], "lb", [
        "sed -i 's/server app1:80;/server app1:8080;/' /etc/nginx/conf.d/shop-lb.conf && systemctl reload nginx",
        "sleep 1; curl -s -H 'Host: shop.example.test' 127.0.0.1 | grep -o 'Shop backend app1 OK'"]))
    ok("[root@lb" in s_lb and "Shop backend app1 OK" in s_lb, "the lb tab is a shell on lb; the shop answers through it")
    try:
        asyncio.run(typing(tech, a["id"], "db", ["true"]))
        refused = False
    except Exception:  # closed before the handshake completes
        refused = True
    ok(refused, "a server the lab does not have is refused")
    ok(tech.post(f"/api/attempts/{a['id']}/complete").status_code == 200, "Complete Test accepted")
    t0 = time.time()
    while time.time() - t0 < 240:
        res = tech.get(f"/api/attempts/{a['id']}/result").json()
        if res["status"] not in ("verifying", "ready"):
            break
        time.sleep(2)
    ok(res["status"] == "completed" and res["percent"] == 100, f"graded on both servers: {res.get('score')}/{res.get('max_score')} ({res.get('percent')}%)")
    review = admin.get(f"/api/admin/attempts/{a['id']}").json()
    nodes = [c["node"] for c in review["commands"]]
    ok(nodes.count("app1") == 4 and nodes.count("lb") == 2, f"review: commands recorded per server ({nodes})")
    ok("$ app1: " in review["final_state"] and "$ lb: " in review["final_state"], "final state collected from both servers")
    ok(admin.get("/api/admin/labs").json()["active"] == 0, "lab slot freed (both servers removed)")
    return a["id"]


if __name__ == "__main__":
    print("attempt", main())
