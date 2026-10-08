import sys, time, uuid
sys.path.insert(0, "/app")
from pathlib import Path
from app.services import scenario_manager as sm
from app.services.lab_manager import LabManager, LabSpec
labs = LabManager(owner="checker")
slug, cmds = sys.argv[1], sys.argv[2:]
pkg = sm.read_package(Path("/srv/scenarios"), slug)
aid = 500000 + uuid.uuid4().int % 99999
try:
    labs.create(LabSpec(attempt_id=aid, image=pkg["docker_image"], cpu=1.0, memory_mb=512, pids_limit=512,
                        capabilities=pkg["extra"]["capabilities"], tmpfs=pkg["extra"]["tmpfs"]))
    labs.wait_ready(aid)
    r = labs.run_script(aid, pkg["setup_script"], timeout=300)
    print("setup exit", r.exit_code, r.output[-int(__import__("os").environ.get("LT_TAIL", "300")):])
    from app.services.scoring import PRELUDE
    if cmds and cmds[0] == "VERIFY":
        r = labs.run_script(aid, PRELUDE + pkg["verify_script"], timeout=120)
        print("verify exit", r.exit_code); print(r.output); cmds = cmds[1:]
    for c in cmds:
        r = labs.exec(aid, ["bash", "-c", c], timeout=60)
        print(f"$ {c}\n{r.output.rstrip()}\n[exit {r.exit_code}]")
finally:
    labs.destroy(aid)
