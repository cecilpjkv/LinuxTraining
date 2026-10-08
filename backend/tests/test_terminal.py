import base64
import time
import uuid

import pytest

from app.services.terminal import CommandParser


def end(code, cwd, cmd):
    b = lambda s: base64.b64encode(s.encode()).decode()
    return f"\x1b]777;lt;e;{code};{b(cwd)};{b(cmd)}\x07".encode()


def test_parser_strips_markers_and_records():
    p = CommandParser()
    stream = b"[root@training ~]# " + b"\x1b]777;lt;s\x07" + b"hello\r\n" + end(0, "/root", "echo hello") + b"[root@training ~]# "
    screen, cmds = p.feed(stream)
    assert b"777" not in screen and screen.endswith(b"]# ")
    assert cmds[0]["command"] == "echo hello" and cmds[0]["exit_code"] == 0 and cmds[0]["output"] == "hello"


def test_parser_marker_split_across_reads():
    p = CommandParser()
    m = b"\x1b]777;lt;s\x07out\r\n" + end(3, "/etc", "false")
    got = []
    screens = b""
    for i in range(0, len(m), 5):  # five bytes at a time
        s, c = p.feed(m[i:i + 5])
        screens += s
        got += c
    assert screens == b"out\r\n" and got[0]["exit_code"] == 3 and got[0]["cwd"] == "/etc"


@pytest.fixture
def lab():
    from app.services.lab_manager import LabManager, LabSpec
    m = LabManager()
    try:
        m.client.images.get("linux-training-base")
    except Exception:
        pytest.skip("no Docker / lab image")
    aid = 800000 + uuid.uuid4().int % 99999
    m.create(LabSpec(attempt_id=aid, image="linux-training-base", cpu=0.5, memory_mb=256, pids_limit=256, capabilities=[], tmpfs={}))
    m.wait_ready(aid)
    yield m, aid
    m.destroy(aid)


def test_real_shell_records_commands(lab, monkeypatch):
    m, aid = lab
    import app.services.terminal as t
    monkeypatch.setattr(t, "labs", m)
    from app.db import SessionLocal
    from app.models import Command, TrainingAttempt, User
    with SessionLocal() as db:  # the attempt row the commands belong to
        u = db.query(User).filter_by(username="tech").one()
        db.add(TrainingAttempt(id=aid, user_id=u.id, scenario_name="t", status="ready"))
        db.commit()
    screen = []
    s = t.TerminalSession(aid, 100, 30)
    s.attach(lambda x: screen.append(x or ""))
    time.sleep(1.5)
    for c in ["cd /etc", "ls hostname", "false", "", "systemctl is-active crond", "echo done"]:
        s.write(c + "\r")
        time.sleep(0.6)
    time.sleep(1)
    text = "".join(screen)
    assert "[root@training" in text and "777;lt" not in text
    s.close()
    s.thread.join(5)
    with SessionLocal() as db:
        rows = db.query(Command).filter_by(attempt_id=aid).order_by(Command.id).all()
    got = [(r.command, r.exit_code, r.cwd) for r in rows]
    assert got == [("cd /etc", 0, "/etc"), ("ls hostname", 0, "/etc"), ("false", 1, "/etc"),
                   ("systemctl is-active crond", 0, "/etc"), ("echo done", 0, "/etc")], got
    assert rows[1].output == "hostname" and rows[3].output == "active"


def test_reattach_replays_screen(lab, monkeypatch):
    m, aid = lab
    import app.services.terminal as t
    monkeypatch.setattr(t, "labs", m)
    s = t.TerminalSession(aid, 100, 30)
    s.attach(lambda x: None)
    time.sleep(1.2)
    s.write("echo marker-$((40+2))\r")
    time.sleep(1)
    replay = s.attach(lambda x: None)  # a second browser takes over
    assert "marker-42" in replay
    s.close()
