"""Admin-changeable system settings (spec §6), stored in system_settings with typed defaults."""
from sqlalchemy.orm import Session

from ..models import SystemSetting

# key: (type, default, minimum, maximum, label)
DEFAULTS: dict[str, tuple[type, float | int, float | int, float | int, str]] = {
    "max_concurrent_tests": (int, 2, 1, 50, "Maximum simultaneous tests"),
    "max_resource_weight": (int, 4, 1, 200, "Maximum resource weight"),
    "lab_cpu": (float, 0.5, 0.1, 8, "CPU per lab (cores)"),
    "lab_memory_mb": (int, 512, 128, 16384, "RAM per lab (MB)"),
    "lab_pids_limit": (int, 512, 64, 8192, "Processes per lab"),
    "max_test_minutes": (int, 120, 5, 600, "Maximum test duration (minutes, caps every scenario)"),
    "idle_abandon_minutes": (int, 20, 2, 600, "Abandon a lab when no terminal is connected for (minutes)"),
}


def get_all(db: Session) -> dict:
    rows = {r.key: r.value for r in db.query(SystemSetting).all()}
    out = {}
    for k, (typ, default, *_rest) in DEFAULTS.items():
        try:
            out[k] = typ(rows[k]) if k in rows else default
        except ValueError:
            out[k] = default
    return out


def update(db: Session, changes: dict) -> dict:
    for k, v in changes.items():
        if k not in DEFAULTS:
            raise ValueError(f"unknown setting {k}")
        typ, _default, lo, hi, _label = DEFAULTS[k]
        try:
            v = typ(v)
        except (TypeError, ValueError):
            raise ValueError(f"{k}: not a number")
        if not lo <= v <= hi:
            raise ValueError(f"{k}: {v} is outside {lo}-{hi}")
        row = db.get(SystemSetting, k)
        if row:
            row.value = str(v)
        else:
            db.add(SystemSetting(key=k, value=str(v)))
    db.commit()
    return get_all(db)


def describe() -> list[dict]:
    return [{"key": k, "type": t.__name__, "default": d, "min": lo, "max": hi, "label": label}
            for k, (t, d, lo, hi, label) in DEFAULTS.items()]
