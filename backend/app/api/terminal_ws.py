import asyncio
import json

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from ..db import SessionLocal
from ..models import TrainingAttempt, User
from ..security import COOKIE, read_token
from ..services.terminal import terminals

router = APIRouter()


@router.websocket("/ws/attempts/{aid}/terminal")
async def terminal(ws: WebSocket, aid: int):
    """Browser terminal: text frames from the server are screen output; the client sends JSON
    {"type": "input", "data": "..."} or {"type": "resize", "cols": n, "rows": n}. Only the technician who owns a
    ready attempt may attach (administrators review the history instead of typing into a technician's lab)."""
    # same-origin only: the session cookie is SameSite=Strict, and the Origin must match the Host
    origin, host = ws.headers.get("origin", ""), ws.headers.get("host", "")
    if origin and origin.split("://", 1)[-1] != host:
        await ws.close(code=4403)
        return
    uid = read_token(ws.cookies.get(COOKIE, ""))
    with SessionLocal() as db:
        user = db.get(User, uid) if uid else None
        a = db.get(TrainingAttempt, aid)
        ok = user and user.active and a and a.user_id == user.id and a.status == "ready"
    if not ok:
        await ws.close(code=4403)
        return
    await ws.accept()
    cols, rows = _int(ws.query_params.get("cols"), 120), _int(ws.query_params.get("rows"), 32)
    loop = asyncio.get_running_loop()
    q: asyncio.Queue = asyncio.Queue(maxsize=2000)

    def listener(text):
        def put():
            try:
                q.put_nowait(text)
            except asyncio.QueueFull:
                pass  # a stalled browser drops output rather than the shell blocking
        loop.call_soon_threadsafe(put)

    try:
        sess = await loop.run_in_executor(None, terminals.get_or_open, aid, cols, rows)
    except Exception:
        await ws.send_text("\r\n[the lab terminal could not be opened]\r\n")
        await ws.close(code=1011)
        return
    replay = sess.attach(listener)
    if replay:
        await ws.send_text(replay)
    sess.resize(cols, rows)

    async def pump_out():
        while True:
            text = await q.get()
            if text is None:
                await ws.send_text("\r\n[session ended]\r\n")
                await ws.close(code=1000)
                return
            await ws.send_text(text)

    sender = asyncio.create_task(pump_out())
    try:
        while True:
            msg = json.loads(await ws.receive_text())
            if msg.get("type") == "input" and isinstance(msg.get("data"), str):
                data = msg["data"][:16384]
                await loop.run_in_executor(None, sess.write, data)
            elif msg.get("type") == "resize":
                sess.resize(_int(msg.get("cols"), 120), _int(msg.get("rows"), 32))
    except (WebSocketDisconnect, json.JSONDecodeError, RuntimeError):
        pass
    finally:
        sender.cancel()
        sess.detach(listener)


def _int(v, default: int) -> int:
    try:
        return int(v)
    except (TypeError, ValueError):
        return default
