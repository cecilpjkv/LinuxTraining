"""Browser smoke test of the real UI (headless Chromium via Playwright), against a running deployment:
admin dashboard and scenario list, technician registration, starting a lab, typing into the xterm.js terminal,
Complete Test, the result page. Screenshots go to OUT_DIR; browser console errors fail the test.
    python ui_smoke.py BASE_URL ADMIN_PASSWORD OUT_DIR
"""
import re
import secrets
import sys

from playwright.sync_api import expect, sync_playwright

BASE, ADMIN_PW, OUT = sys.argv[1].rstrip("/"), sys.argv[2], sys.argv[3]
errors = []


def ok(cond, what):
    print(("ok   " if cond else "FAIL ") + what, flush=True)
    if not cond:
        raise SystemExit(1)


def watch(page):
    page.on("console", lambda m: m.type == "error" and errors.append(m.text))
    page.on("pageerror", lambda e: errors.append(str(e)))


with sync_playwright() as p:
    browser = p.chromium.launch()
    # --- administrator
    a = browser.new_page(viewport={"width": 1280, "height": 900})
    watch(a)
    a.goto(f"{BASE}/")
    a.get_by_label("Username or e-mail").fill("admin")
    a.get_by_label("Password").fill(ADMIN_PW)
    a.get_by_role("button", name="Log in").click()
    expect(a.get_by_role("heading", name="Dashboard")).to_be_visible()
    expect(a.locator(".stat", has_text="Scenarios")).to_contain_text("50")
    a.screenshot(path=f"{OUT}/1-admin-dashboard.png", full_page=True)
    ok(True, "admin logs in; dashboard shows 50 scenarios")
    a.get_by_role("link", name="Scenarios").click()
    expect(a.get_by_role("heading", name=re.compile(r"Scenarios \(50\)"))).to_be_visible()
    expect(a.locator("tbody tr")).to_have_count(50)
    ok(True, "scenario list has 50 rows")
    a.screenshot(path=f"{OUT}/2-admin-scenarios.png")
    a.get_by_role("link", name="Website down after a configuration change").click()
    expect(a.get_by_label(re.compile("Setup script"))).to_have_value(re.compile("colleague"))
    ok(True, "scenario editor shows the scripts")

    # --- technician
    t = browser.new_page(viewport={"width": 1280, "height": 900})
    watch(t)
    user = "ui" + secrets.token_hex(3)
    t.goto(f"{BASE}/register")
    t.get_by_label("Username").fill(user)
    t.get_by_label(re.compile("^Password")).fill("ui-smoke-password-1")
    t.get_by_role("button", name="Create account").click()
    expect(t.get_by_role("heading", name="Scenarios")).to_be_visible()
    expect(t.locator("article.scenario")).to_have_count(50)  # loaded after the heading appears
    ok(True, "technician sees 50 scenario cards")
    t.screenshot(path=f"{OUT}/3-tech-scenarios.png")
    t.get_by_placeholder("Search").fill("Customer portal unreachable")
    card = t.locator("article.scenario", has_text="Customer portal unreachable")
    card.get_by_role("button", name="Start test").click()
    expect(t.get_by_text("In progress")).to_be_visible(timeout=120_000)
    term = t.locator(".xterm-rows")
    expect(term).to_contain_text("[root@training", timeout=30_000)
    t.screenshot(path=f"{OUT}/4-lab-terminal.png")
    ok(True, "lab ready; the xterm.js terminal shows the prompt")
    t.locator(".xterm-helper-textarea").focus()
    for line in ["systemctl status httpd --no-pager | head -3", "systemctl enable --now httpd",
                 "curl -s -H 'Host: portal.example.test' 127.0.0.1 | grep -o 'Portal OK'"]:
        t.keyboard.type(line)
        t.keyboard.press("Enter")
        t.wait_for_timeout(2500)
    expect(term).to_contain_text("Portal OK")
    t.screenshot(path=f"{OUT}/5-lab-fixed.png")
    ok(True, "typed the fix in the browser terminal")
    t.once("dialog", lambda d: d.accept())
    t.get_by_role("button", name="Complete Test").click()
    expect(t.get_by_role("heading", name="Result")).to_be_visible(timeout=120_000)
    expect(t.locator(".big")).to_contain_text("PASSED")
    t.screenshot(path=f"{OUT}/6-result.png", full_page=True)
    ok(True, "Complete Test -> result page: " + t.locator(".big").inner_text())

    # --- administrator reviews it
    a.goto(f"{BASE}/admin/attempts")
    a.locator("tbody tr", has_text=user).first.get_by_role("link").first.click()
    expect(a.get_by_role("heading", name=re.compile(r"Command history \(3\)"))).to_be_visible()
    expect(a.get_by_text("PASS").first).to_be_visible()
    a.screenshot(path=f"{OUT}/7-admin-review.png", full_page=True)
    ok(True, "admin review shows the 3 commands and the verification")
    browser.close()

ok(not errors, f"no browser console errors{': ' + '; '.join(errors[:3]) if errors else ''}")
print("attempt user:", user)
