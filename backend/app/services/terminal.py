"""Terminal sessions (spec §9-10), kept apart from Docker management: the Lab Manager hands over an interactive TTY
exec, this module relays it and records the command history.

One shell per attempt. It outlives a browser disconnect: reconnecting re-attaches to the same shell and replays the
recent screen output. The shell's hooks (images/base/lt-shell-hooks.sh) print OSC 777 sequences:
    ESC ] 777 ; lt ; s BEL                          a command starts (PS0)
    ESC ] 777 ; lt ; e ; EXIT ; B64(cwd) ; B64(cmd) BEL   it ended (PROMPT_COMMAND)
They are removed from the stream and turned into Command rows with the output in between (truncated).
"""
import base64
import codecs
import logging
import re
import socket
import threading
import time
import uuid
from collections.abc import Callable
from datetime import datetime, timezone

from ..db import SessionLocal
from ..models import Command
from .lab_manager import labs

log = logging.getLogger("terminal")

MARK = re.compile(rb"\x1b\]777;lt;(s|e;(-?\d+);([A-Za-z0-9+/=]*);([A-Za-z0-9+/=]*))\x07")
SCROLLBACK = 64 * 1024
OUTPUT_KEEP = 8 * 1024  # output stored per command
ANSI = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07]*\x07|\x1b[()][A-Z0-9]|\r")


def clean(text: str) -> str:
    return ANSI.sub("", text)


class CommandParser:
    """Feeds raw terminal bytes, returns (bytes for the screen, finished commands). Markers split across reads are
    held back until complete."""

    def __init__(self) -> None:
        self.pending = b""
        self.cur_out = bytearray()
        self.cur_start: datetime | None = None

    def feed(self, data: bytes) -> tuple[bytes, list[dict]]:
        data = self.pending + data
        self.pending = b""
        # keep a possible partial marker at the end for the next read: a started one without its BEL, or a tail
        # that may be the start of one (found by the tests: a read ending in "\x1b]7" reached the screen)
        cut = data.rfind(b"\x1b]777;")
        if cut != -1 and data.find(b"\x07", cut) == -1 and len(data) - cut < 4096:
            data, self.pending = data[:cut], data[cut:]
        else:
            head = b"\x1b]777;"
            for n in range(min(len(head) - 1, len(data)), 0, -1):
                if data.endswith(head[:n]):
                    data, self.pending = data[:-n], data[-n:]
                    break
        screen = bytearray()
        done = []
        pos = 0
        for m in MARK.finditer(data):
            chunk = data[pos:m.start()]
            screen += chunk
            self._out(chunk)
            pos = m.end()
            if m.group(1) == b"s":
                self.cur_start, self.cur_out = datetime.now(timezone.utc), bytearray()
            else:
                try:
                    cwd = base64.b64decode(m.group(3)).decode("utf-8", "replace")
                    cmd = base64.b64decode(m.group(4)).decode("utf-8", "replace")
                except ValueError:
                    continue
                out = clean(bytes(self.cur_out).decode("utf-8", "replace"))
                done.append({"command": cmd[:4000], "exit_code": int(m.group(2)), "cwd": cwd[:500],
                             "at": self.cur_start or datetime.now(timezone.utc), "output": _trim(out)})
                self.cur_start, self.cur_out = None, bytearray()
        rest = data[pos:]
        screen += rest
        self._out(rest)
        return bytes(screen), done

    def _out(self, b: bytes) -> None:
        if self.cur_start is not None and len(self.cur_out) < OUTPUT_KEEP * 2:
            self.cur_out += b


def _trim(s: str) -> str:
    s = s.strip("\n")
    if len(s) > OUTPUT_KEEP:
        return s[:OUTPUT_KEEP // 2] + "\n[… output truncated …]\n" + s[-OUTPUT_KEEP // 2:]
    return s


class TerminalSession:
    def __init__(self, attempt_id: int, cols: int, rows: int):
        self.attempt_id = attempt_id
        self.id = uuid.uuid4().hex[:12]
        self.exec_id, self.sock = labs.shell(attempt_id, cols, rows)
        self.parser = CommandParser()
        self.scroll = bytearray()
        self.listener: Callable[[str | None], None] | None = None  # gets screen text; None = session ended
        self.lock = threading.Lock()
        self.closed = False
        self.last_activity = time.monotonic()
        self.decoder = codecs.getincrementaldecoder("utf-8")("replace")
        self.thread = threading.Thread(target=self._pump, name=f"term-{attempt_id}", daemon=True)
        self.thread.start()

    def _pump(self) -> None:
        try:
            while True:
                data = self.sock.recv(65536)
                if not data:
                    break
                screen, cmds = self.parser.feed(data)
                if cmds:
                    self._store(cmds)
                if screen:
                    text = self.decoder.decode(screen)
                    with self.lock:
                        self.scroll += screen
                        if len(self.scroll) > SCROLLBACK:
                            del self.scroll[:len(self.scroll) - SCROLLBACK]
                        listener = self.listener
                    if listener and text:
                        listener(text)
        except OSError:
            pass
        finally:
            self.closed = True
            with self.lock:
                listener = self.listener
            if listener:
                listener(None)

    def _store(self, cmds: list[dict]) -> None:
        try:
            with SessionLocal() as db:
                db.add_all([Command(attempt_id=self.attempt_id, session_id=self.id, at=c["at"], command=c["command"],
                                    output=c["output"], exit_code=c["exit_code"], cwd=c["cwd"]) for c in cmds])
                db.commit()
        except Exception as e:  # history must not take the terminal down
            log.error("attempt %s: could not store %d commands: %s", self.attempt_id, len(cmds), e)

    def attach(self, listener: Callable[[str | None], None]) -> str:
        """Makes listener the receiver of output (replacing an earlier browser) and returns the replay."""
        with self.lock:
            self.listener = listener
            return bytes(self.scroll).decode("utf-8", "replace")

    def detach(self, listener) -> None:
        with self.lock:
            if self.listener is listener:
                self.listener = None

    def write(self, data: str) -> None:
        if self.closed:
            return
        self.last_activity = time.monotonic()
        try:
            self.sock.sendall(data.encode())
        except OSError:
            self.closed = True

    def resize(self, cols: int, rows: int) -> None:
        labs.resize(self.exec_id, max(10, min(cols, 500)), max(5, min(rows, 200)))

    def close(self) -> None:
        self.closed = True
        try:
            self.sock.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        try:
            self.sock.close()
        except OSError:
            pass


class Terminals:
    """The live sessions, one per attempt."""

    def __init__(self) -> None:
        self._s: dict[int, TerminalSession] = {}
        self._lock = threading.Lock()

    def get_or_open(self, attempt_id: int, cols: int, rows: int) -> TerminalSession:
        with self._lock:
            s = self._s.get(attempt_id)
            if s is None or s.closed:
                s = TerminalSession(attempt_id, cols, rows)
                self._s[attempt_id] = s
            return s

    def close(self, attempt_id: int) -> None:
        with self._lock:
            s = self._s.pop(attempt_id, None)
        if s:
            s.close()
            s.thread.join(timeout=5)  # the last commands are stored before the lab is graded

    def attached(self, attempt_id: int) -> bool:
        s = self._s.get(attempt_id)
        return bool(s and not s.closed and s.listener)


terminals = Terminals()
