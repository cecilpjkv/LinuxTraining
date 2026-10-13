import sys, time, uuid
sys.path.insert(0, "/app")
from pathlib import Path
from app.services import scenario_manager as sm
from app.services.lab_manager import LabManager, node_key
import app.services.lab_manager as _lm
from app.services.scheduler import spec_for
labs = LabManager(owner="checker")
_lm.labs = labs
slug, cmds = sys.argv[1], sys.argv[2:]
pkg = sm.read_package(Path("/srv/scenarios"), slug)
aid = 500000 + uuid.uuid4().int % 99999
try:
    extra = pkg["extra"]
    labs.create(spec_for(aid, pkg["docker_image"], extra, {"lab_cpu": 1.0, "lab_memory_mb": 512, "lab_pids_limit": 512}))
    labs.wait_all(aid, extra)
    for node, r in labs.run_on_nodes(aid, extra, pkg["setup_script"], timeout=300, setup_order=True):
        print(f"setup exit {r.exit_code} ({node})", r.output[-int(__import__("os").environ.get("LT_TAIL", "300")):])
    from app.services.scoring import run_verify
    if cmds and cmds[0] == "VERIFY":
        r = run_verify(aid, pkg["verify_script"], extra=extra)
        print("verify exit", r.exit_code); print(r.output); cmds = cmds[1:]
    for c in cmds:  # "NODE: command" runs on another server of a multi-server lab
        node, _, cmd = c.partition(": ") if ": " in c and c.split(": ", 1)[0].isidentifier() else ("", "", c)
        r = labs.exec(aid, ["bash", "-c", cmd], timeout=60, node=node_key(extra, node))
        print(f"$ {c}\n{r.output.rstrip()}\n[exit {r.exit_code}]")
finally:
    labs.destroy(aid)
