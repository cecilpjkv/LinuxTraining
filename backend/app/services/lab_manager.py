"""Lab Manager (spec §5): the only code that talks to Docker (the lab daemon, deploy/docker-labs). Each attempt gets
one container, named training-attempt-<id>, on its own internal network whose bridge is lt-<id> (the host's
lt-labs-firewall drops everything from and to lt-* bridges: no internet, no other lab, not the host), with
CPU/memory/PID limits and no host mounts. Scenario scripts are streamed to bash over stdin: they run only inside the container and leave no
copy there for the technician to read."""
import logging
import socket
import struct
import time
from dataclasses import dataclass

import docker
from docker.errors import APIError, NotFound

log = logging.getLogger("lab")

LABEL = "lt.managed"
PREFIX = "training-attempt-"


@dataclass
class ExecResult:
    exit_code: int
    output: str
    timed_out: bool = False


@dataclass
class LabSpec:
    attempt_id: int
    image: str
    cpu: float
    memory_mb: int
    pids_limit: int
    capabilities: list[str]
    tmpfs: dict[str, int]


class LabManager:
    def __init__(self, client: docker.DockerClient | None = None):
        self._client = client

    @property
    def client(self) -> docker.DockerClient:
        if self._client is None:
            self._client = docker.from_env(timeout=120)
        return self._client

    # --- network ---

    @staticmethod
    def network_name(attempt_id: int) -> str:
        return f"lt-lab-{attempt_id}"

    def create_network(self, attempt_id: int) -> str:
        name = self.network_name(attempt_id)
        try:
            self.client.networks.get(name).remove()
        except NotFound:
            pass
        self.client.networks.create(name, driver="bridge", internal=True, labels={LABEL: "1", "lt.attempt": str(attempt_id)},
                                    options={"com.docker.network.bridge.name": f"lt-{attempt_id}"[:15]})
        return name

    def remove_network(self, attempt_id: int) -> None:
        try:
            self.client.networks.get(self.network_name(attempt_id)).remove()
        except (NotFound, APIError):
            pass

    # --- lifecycle ---

    @staticmethod
    def name(attempt_id: int) -> str:
        return f"{PREFIX}{attempt_id}"

    def create(self, spec: LabSpec) -> str:
        network = self.create_network(spec.attempt_id)
        tmpfs = {"/run": "rw,nosuid,nodev,size=64m", "/run/lock": "rw,nosuid,nodev,size=8m"}
        for path, mb in spec.tmpfs.items():
            tmpfs[path] = f"rw,size={mb}m"
        c = self.client.containers.run(
            spec.image, name=self.name(spec.attempt_id), hostname="training", detach=True,
            network=network, cgroupns="private",
            cap_add=["SYS_ADMIN", *spec.capabilities],  # SYS_ADMIN: systemd's cgroups (see images/base/lab-init)
            tmpfs=tmpfs,
            nano_cpus=int(spec.cpu * 1e9), mem_limit=f"{spec.memory_mb}m", memswap_limit=f"{spec.memory_mb}m",
            pids_limit=spec.pids_limit,
            ulimits=[docker.types.Ulimit(name="nofile", soft=65536, hard=65536)],
            labels={LABEL: "1", "lt.attempt": str(spec.attempt_id)},
            log_config=docker.types.LogConfig(type="local", config={"max-size": "1m", "max-file": "2"}),
            stop_signal="SIGRTMIN+3",
        )
        return c.id

    def wait_ready(self, attempt_id: int, timeout: int = 90) -> str:
        """Waits until systemd finished booting (running or degraded)."""
        end = time.monotonic() + timeout
        state = ""
        while time.monotonic() < end:
            r = self.exec(attempt_id, ["systemctl", "is-system-running"], timeout=15)
            state = r.output.strip()
            if state in ("running", "degraded"):
                return state
            time.sleep(1)
        raise TimeoutError(f"the lab did not finish booting (systemd: {state or 'no answer'})")

    def destroy(self, attempt_id: int) -> bool:
        try:
            self.client.containers.get(self.name(attempt_id)).remove(force=True, v=True)
            found = True
        except NotFound:
            found = False
        self.remove_network(attempt_id)
        return found

    def running(self, attempt_id: int) -> bool:
        try:
            return self.client.containers.get(self.name(attempt_id)).status == "running"
        except NotFound:
            return False

    def managed(self) -> list[dict]:
        """Every lab container Docker knows about (for cleanup of orphans)."""
        out = []
        for c in self.client.containers.list(all=True, filters={"label": LABEL}):
            out.append({"name": c.name, "status": c.status, "attempt": c.labels.get("lt.attempt")})
        seen = {o["attempt"] for o in out}
        for n in self.client.networks.list(filters={"label": LABEL}):  # a network left without its container
            if n.attrs.get("Labels", {}).get("lt.attempt") not in seen:
                out.append({"name": n.name, "status": "network", "attempt": n.attrs.get("Labels", {}).get("lt.attempt")})
        return out

    # --- running things inside ---

    def exec(self, attempt_id: int, cmd: list[str], stdin: str | None = None, timeout: int = 60,
             max_output: int = 256 * 1024) -> ExecResult:
        """Runs cmd in the lab (as root, not a TTY), optionally feeding stdin; output is stdout+stderr, bounded."""
        api = self.client.api
        cid = self.name(attempt_id)
        ex = api.exec_create(cid, ["timeout", "-k", "5", str(timeout), *cmd], stdin=stdin is not None, stdout=True,
                             stderr=True, tty=False, environment={"LC_ALL": "C", "TERM": "dumb"})
        sock = api.exec_start(ex["Id"], socket=True)
        raw: socket.socket = getattr(sock, "_sock", sock)
        raw.settimeout(timeout + 15)
        try:
            if stdin is not None:
                raw.sendall(stdin.encode())
                raw.shutdown(socket.SHUT_WR)
            out = _read_multiplexed(raw, max_output)
        finally:
            raw.close()
        code = api.exec_inspect(ex["Id"]).get("ExitCode")
        code = -1 if code is None else code
        return ExecResult(exit_code=code, output=out, timed_out=code == 124)

    def run_script(self, attempt_id: int, script: str, timeout: int = 120) -> ExecResult:
        return self.exec(attempt_id, ["bash", "-s"], stdin=script, timeout=timeout)

    def shell(self, attempt_id: int, cols: int = 120, rows: int = 32):
        """An interactive TTY exec for the browser terminal (images/base/lab-shell drops SYS_ADMIN). Returns
        (exec_id, raw socket)."""
        api = self.client.api
        ex = api.exec_create(self.name(attempt_id), ["/usr/local/sbin/lab-shell"], stdin=True, stdout=True, stderr=True,
                             tty=True, environment={"TERM": "xterm-256color", "LANG": "C.UTF-8", "COLUMNS": str(cols),
                                                    "LINES": str(rows)})
        sock = api.exec_start(ex["Id"], socket=True, tty=True)
        raw = getattr(sock, "_sock", sock)
        try:
            api.exec_resize(ex["Id"], height=rows, width=cols)
        except APIError:
            pass
        return ex["Id"], raw

    def resize(self, exec_id: str, cols: int, rows: int) -> None:
        try:
            self.client.api.exec_resize(exec_id, height=rows, width=cols)
        except APIError:
            pass


def _read_multiplexed(raw: socket.socket, limit: int) -> str:
    """Docker's stream format without a TTY: 8-byte header (stream, 0, 0, 0, size) + payload."""
    buf = b""
    out = bytearray()
    while True:
        try:
            chunk = raw.recv(65536)
        except socket.timeout:
            break
        if not chunk:
            break
        buf += chunk
        while len(buf) >= 8:
            size = struct.unpack(">I", buf[4:8])[0]
            if len(buf) < 8 + size:
                break
            if len(out) < limit:
                out += buf[8:8 + size]
            buf = buf[8 + size:]
    text = out[:limit].decode("utf-8", "replace")
    if len(out) > limit:
        text += "\n[output truncated]"
    return text


labs = LabManager()
