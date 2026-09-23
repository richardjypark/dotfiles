import os
import tempfile
from pathlib import Path

import yaml

def main():
    config_path = Path(os.environ["HERMES_CONFIG_PATH"])
    shared_entry = os.environ["HERMES_SHARED_SKILLS_ENTRY"]
    shared_path = Path(os.path.expanduser(os.path.expandvars(shared_entry))).resolve()

    try:
        config = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
    except FileNotFoundError:
        config = {}

    if not isinstance(config, dict):
        raise SystemExit(0)

    skills = config.setdefault("skills", {})
    if not isinstance(skills, dict):
        raise SystemExit(0)

    raw_dirs = skills.get("external_dirs")
    changed = False


    def same_path(value):
        try:
            candidate = Path(os.path.expanduser(os.path.expandvars(str(value)))).resolve()
        except (OSError, RuntimeError):
            return False
        return candidate == shared_path


    if raw_dirs in (None, ""):
        skills["external_dirs"] = [shared_entry]
        changed = True
    elif isinstance(raw_dirs, str):
        if not same_path(raw_dirs):
            skills["external_dirs"] = [raw_dirs, shared_entry]
            changed = True
    elif isinstance(raw_dirs, list):
        if not any(same_path(entry) for entry in raw_dirs):
            raw_dirs.append(shared_entry)
            changed = True

    if not changed:
        raise SystemExit(0)

    config_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        mode = config_path.stat().st_mode & 0o777
    except FileNotFoundError:
        mode = 0o600

    fd, tmp_name = tempfile.mkstemp(
        dir=str(config_path.parent),
        prefix=f".{config_path.name}.",
        suffix=".tmp",
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as tmp:
            yaml.safe_dump(config, tmp, sort_keys=False, default_flow_style=False)
            tmp.flush()
            os.fsync(tmp.fileno())
        os.chmod(tmp_name, mode)
        os.replace(tmp_name, config_path)
    finally:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass


if __name__ == "__main__":
    main()
