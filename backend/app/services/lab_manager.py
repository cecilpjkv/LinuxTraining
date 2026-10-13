"""Lab Manager (spec §5): the only code that talks to Docker (the lab daemon, deploy/docker-labs). Each attempt gets
one container, named training-attempt-<id>, on its own internal network whose bridge is lt-<id> (the host's
lt-labs-firewall drops everything from and to lt-* bridges: no internet, no other lab, not the host), with
CPU/memory/PID limits and no host mounts. Scenario scripts are streamed to bash over stdin: they run only inside the container and leave no
copy there for the technician to read.

A lab can have several servers (scenario option `nodes`): the first is training-attempt-<id> (where the terminal opens),
the others training-attempt-<id>-<node>, all on the lab's network, where each answers to its node name."""
import logging
import re
import socket
import struct
import time
from dataclasses import dataclass

import docker
from docker.errors import APIError, NotFound

log = logging.getLogger("lab")

LABEL = "lt.managed"
# Docker's read-only /proc paths (MaskedPaths stay Docker's default)
DEFAULT_READONLY_PATHS = ["/proc/bus", "/proc/fs", "/proc/irq", "/proc/sys", "/proc/sysrq-trigger"]
PREFIX = "training-attempt-"
SHARE = re.compile(r"^@@LT SHARE ([A-Z][A-Z0-9_]{0,31}) ([A-Za-z0-9+/=._:-]{1,8192})$", re.M)


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
    tmpfs: dict[str, dict | int]
    nodes: list[dict] | None = None  # [{name, image}], the first one is the main server; None: one server
    nested: bool = False  # the lab runs containers itself (writable /proc/sys for the container engine's network)


def node_list(extra: dict | None) -> list[tuple[str, str | None]]:
    """(node name, container key) for every server of a lab: the key is None for the main server (the container named
    after the attempt alone). A one-server lab is [("training", None)]."""
    nodes = (extra or {}).get("nodes") or []
    if not nodes:
        return [("training", None)]
    return [(n["name"], None if i == 0 else n["name"]) for i, n in enumerate(nodes)]


def node_key(extra: dict | None, name: str | None) -> str | None:
    """The container key of the node called name (None or "": the main server); KeyError if the lab has no such node."""
    for n, key in node_list(extra):
        if not name or n == name:
            return key
    raise KeyError(name)


class LabManager:
    def __init__(self, client: docker.DockerClient | None = None, owner: str = "backend"):
        self._client = client
        # labs of other tools (the scenario checker) carry their owner: the backend's orphan cleanup leaves them
        # alone (found: it destroyed the checker's labs mid-run, their attempts are not in the database)
        self.owner = owner

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
        self.client.networks.create(name, driver="bridge", internal=True, labels={LABEL: "1", "lt.attempt": str(attempt_id), "lt.owner": self.owner},
                                    options={"com.docker.network.bridge.name": f"lt-{attempt_id}"[:15]})
        return name

    def remove_network(self, attempt_id: int) -> None:
        try:
            self.client.networks.get(self.network_name(attempt_id)).remove()
        except (NotFound, APIError):
            pass

    # --- lifecycle ---

    @staticmethod
    def name(attempt_id: int, node: str | None = None) -> str:
        return f"{PREFIX}{attempt_id}" + (f"-{node}" if node else "")

    def create(self, spec: LabSpec) -> str:
        """Creates the lab's network and its servers; returns the main server's container id."""
        network = self.create_network(spec.attempt_id)
        tmpfs = {"/run": "rw,nosuid,nodev,size=64m", "/run/lock": "rw,nosuid,nodev,size=8m"}
        for path, t in spec.tmpfs.items():
            t = {"size": t} if isinstance(t, int) else t
            tmpfs[path] = f"rw,size={t['size']}m" + (f",nr_inodes={t['inodes']}" if t.get("inodes") else "")
        nodes = spec.nodes or [{"name": "training", "image": spec.image}]
        # a container engine inside also manages the lab's own network interfaces (its namespace, not the host's)
        caps = ["SYS_ADMIN", *spec.capabilities, *(["NET_ADMIN"] if spec.nested and "NET_ADMIN" not in spec.capabilities else [])]
        api = self.client.api
        first = None
        for i, node in enumerate(nodes):
            key = None if i == 0 else node["name"]
            hc = api.create_host_config(
                network_mode=network, cgroupns="private",
                cap_add=caps,  # SYS_ADMIN: systemd's cgroups (see images/base/lab-init)
                tmpfs=tmpfs,
                nano_cpus=int(spec.cpu * 1e9), mem_limit=f"{spec.memory_mb}m", memswap_limit=f"{spec.memory_mb}m",
                pids_limit=spec.pids_limit,
                ulimits=[docker.types.Ulimit(name="nofile", soft=65536, hard=65536)],
                log_config=docker.types.LogConfig(type="local", config={"max-size": "1m", "max-file": "2"}),
            )
            if spec.nested:
                # the container engine inside sets network sysctls of the lab's own namespace: /proc/sys is writable
                # (the user namespace keeps every host-wide sysctl read-only), the other read-only paths stay
                hc["ReadonlyPaths"] = [p for p in DEFAULT_READONLY_PATHS if p != "/proc/sys"]
            net = None
            if spec.nodes:  # the other servers find this one by its node name
                net = api.create_networking_config({network: api.create_endpoint_config(aliases=[node["name"]])})
            c = api.create_container(
                node["image"], name=self.name(spec.attempt_id, key), hostname=node["name"], detach=True,
                host_config=hc, networking_config=net, stop_signal="SIGRTMIN+3",
                labels={LABEL: "1", "lt.attempt": str(spec.attempt_id), "lt.owner": self.owner, "lt.node": node["name"]},
            )
            api.start(c["Id"])
            first = first or c["Id"]
        return first

    def wait_ready(self, attempt_id: int, timeout: int = 90, node: str | None = None) -> str:
        """Waits until systemd finished booting (running or degraded)."""
        end = time.monotonic() + timeout
        state = ""
        while time.monotonic() < end:
            r = self.exec(attempt_id, ["systemctl", "is-system-running"], timeout=15, node=node)
            state = r.output.strip()
            if state in ("running", "degraded"):
                return state
            time.sleep(1)
        raise TimeoutError(f"the lab{f' server {node}' if node else ''} did not finish booting (systemd: {state or 'no answer'})")

    def wait_all(self, attempt_id: int, extra: dict | None, timeout: int = 90) -> None:
        for _name, key in node_list(extra):
            self.wait_ready(attempt_id, timeout, node=key)

    def destroy(self, attempt_id: int, wait: int = 60) -> bool:
        """Removes the lab's containers (every server) and network. Idempotent: "removal already in progress" (409,
        found by the scenario checker) waits for that removal instead of failing."""
        names = {self.name(attempt_id)}
        try:
            names |= {c.name for c in self.client.containers.list(all=True, filters={"label": f"lt.attempt={attempt_id}"})
                      if c.name.startswith(f"{PREFIX}{attempt_id}-")}
        except APIError:
            pass
        found = False
        for name in sorted(names):
            try:
                self.client.containers.get(name).remove(force=True, v=True)
                found = True
            except NotFound:
                pass
            except APIError as e:
                if e.status_code != 409:
                    raise
                found = True
                end = time.monotonic() + wait
                while time.monotonic() < end:
                    try:
                        self.client.containers.get(name)
                    except NotFound:
                        break
                    time.sleep(0.5)
        self.remove_network(attempt_id)
        return found

    def running(self, attempt_id: int) -> bool:
        try:
            return self.client.containers.get(self.name(attempt_id)).status == "running"
        except NotFound:
            return False

    def managed(self) -> list[dict]:
        """Every lab container Docker knows about (for cleanup of orphans)."""
        out, seen = [], set()
        for c in self.client.containers.list(all=True, filters={"label": LABEL}):
            seen.add(c.labels.get("lt.attempt"))
            if self._foreign_and_fresh(c.labels, c.attrs.get("Created", "")):
                continue
            out.append({"name": c.name, "status": c.status, "attempt": c.labels.get("lt.attempt")})
        for n in self.client.networks.list(filters={"label": LABEL}):  # a network left without its container
            labels = n.attrs.get("Labels", {}) or {}
            if labels.get("lt.attempt") not in seen and not self._foreign_and_fresh(labels, n.attrs.get("Created", "")):
                out.append({"name": n.name, "status": "network", "attempt": labels.get("lt.attempt")})
        return out

    def _foreign_and_fresh(self, labels: dict, created: str) -> bool:
        """Another owner's lab younger than an hour (older ones are left over from a crashed tool and cleaned)."""
        if labels.get("lt.owner", "backend") == self.owner:
            return False
        try:
            from datetime import datetime, timezone
            t = datetime.fromisoformat(created[:26].rstrip("Z") + "+00:00") if created else None
        except ValueError:
            t = None
        return t is None or (datetime.now(timezone.utc) - t).total_seconds() < 3600

    # --- running things inside ---

    def exec(self, attempt_id: int, cmd: list[str], stdin: str | None = None, timeout: int = 60,
             max_output: int = 256 * 1024, node: str | None = None) -> ExecResult:
        """Runs cmd in the lab (as root, not a TTY), optionally feeding stdin; output is stdout+stderr, bounded."""
        api = self.client.api
        cid = self.name(attempt_id, node)
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

    def run_script(self, attempt_id: int, script: str, timeout: int = 120, node: str | None = None) -> ExecResult:
        return self.exec(attempt_id, ["bash", "-s"], stdin=script, timeout=timeout, node=node)

    def run_on_nodes(self, attempt_id: int, extra: dict | None, script: str, timeout: int = 120,
                     setup_order: bool = False) -> list[tuple[str, ExecResult]]:
        """Runs a scenario script on every server of the lab, with LT_NODE (this server's name) and LT_NODES (all of
        them) set. setup_order: the main server last, so its setup can rely on the others being in place.
        A run may hand values to the runs after it: an output line "@@LT SHARE NAME VALUE" becomes LT_SHARE_NAME
        (for example a key pair made on one server and needed on another; VALUE has no spaces: base64 it)."""
        nodes = node_list(extra)
        names = " ".join(n for n, _ in nodes)
        out, shares = [], {}
        for name, key in (nodes[1:] + nodes[:1]) if setup_order else nodes:
            env = ""
            if len(nodes) > 1:
                env = f"export LT_NODE={name} LT_NODES='{names}'" + "".join(f" LT_SHARE_{k}={v}" for k, v in shares.items()) + "\n"
            r = self.run_script(attempt_id, env + script, timeout=timeout, node=key)
            for m in SHARE.finditer(r.output):
                shares[m.group(1)] = m.group(2)
            r.output = SHARE.sub("@@LT SHARE \\1 [hidden]", r.output)
            out.append((name, r))
        return out

    def shell(self, attempt_id: int, cols: int = 120, rows: int = 32, node: str | None = None):
        """An interactive TTY exec for the browser terminal (images/base/lab-shell drops SYS_ADMIN). Returns
        (exec_id, raw socket)."""
        api = self.client.api
        ex = api.exec_create(self.name(attempt_id, node), ["/usr/local/sbin/lab-shell"], stdin=True, stdout=True, stderr=True,
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
