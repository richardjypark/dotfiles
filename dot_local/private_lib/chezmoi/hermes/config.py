"""Converge public Hermes preferences without touching credential files."""

import os
import tempfile
from pathlib import Path

import yaml


PREFERENCES = {
    "model": {"provider": "HERMES_MODEL_PROVIDER", "default": "HERMES_MODEL",
              "base_url": "HERMES_MODEL_BASE_URL", "api_key": None, "api_mode": None,
              "context_length": ("HERMES_CONTEXT_LENGTH", int)},
    "display": {"show_reasoning": ("HERMES_SHOW_REASONING", bool)},
    "agent": {"reasoning_effort": "HERMES_REASONING_EFFORT",
              "service_tier": "HERMES_SERVICE_TIER", "max_turns": ("HERMES_AGENT_MAX_TURNS", int)},
    "goals": {"max_turns": ("HERMES_GOALS_MAX_TURNS", int)},
    "delegation": {"provider": "HERMES_DELEGATION_PROVIDER", "model": "HERMES_DELEGATION_MODEL",
                   "reasoning_effort": "HERMES_DELEGATION_REASONING_EFFORT"},
}


def desired_value(spec):
    if spec is None:
        return ""
    if isinstance(spec, str):
        return os.environ[spec]
    name, value_type = spec
    raw = os.environ[name]
    if value_type is bool:
        if raw.lower() not in ("true", "false"):
            raise ValueError("invalid public boolean preference")
        return raw.lower() == "true"
    value = value_type(raw)
    if value_type is int and value < 1:
        raise ValueError("invalid public integer preference")
    return value


def same_path(value, shared_path):
    try:
        candidate = Path(os.path.expanduser(os.path.expandvars(str(value)))).resolve()
    except (OSError, RuntimeError):
        return False
    return candidate == shared_path


def converge(config):
    changed = False
    if isinstance(config.get("model"), str) and config["model"]:
        config["model"] = {"default": config["model"]}
        changed = True
    for section_name, values in PREFERENCES.items():
        section = config.setdefault(section_name, {})
        if not isinstance(section, dict):
            raise ValueError(f"incompatible Hermes section: {section_name}")
        for key, spec in values.items():
            desired = desired_value(spec)
            current = section.get(key)
            if key not in section or type(current) is not type(desired) or current != desired:
                section[key] = desired
                changed = True

    shared_entry = os.environ.get("HERMES_SHARED_SKILLS_ENTRY")
    if shared_entry and Path(os.path.expanduser(shared_entry)).is_dir():
        skills = config.setdefault("skills", {})
        if not isinstance(skills, dict):
            raise ValueError("incompatible Hermes section: skills")
        raw_dirs = skills.get("external_dirs")
        shared_path = Path(os.path.expanduser(os.path.expandvars(shared_entry))).resolve()
        if raw_dirs in (None, ""):
            skills["external_dirs"] = [shared_entry]
            changed = True
        elif isinstance(raw_dirs, str):
            if not same_path(raw_dirs, shared_path):
                skills["external_dirs"] = [raw_dirs, shared_entry]
                changed = True
        elif isinstance(raw_dirs, list):
            if not any(same_path(entry, shared_path) for entry in raw_dirs):
                raw_dirs.append(shared_entry)
                changed = True
        else:
            raise ValueError("incompatible Hermes skills.external_dirs")
    return changed


def main():
    config_path = Path(os.environ["HERMES_CONFIG_PATH"])
    try:
        original = config_path.read_bytes()
        config = yaml.safe_load(original)
        if config is None and not original.strip():
            config = {}
    except FileNotFoundError:
        original = None
        config = {}
    except yaml.YAMLError as exc:
        raise ValueError("malformed Hermes YAML; preferences were not changed") from exc
    if not isinstance(config, dict):
        raise ValueError("Hermes config must be a mapping")
    if not converge(config):
        if original is not None:
            mode = config_path.stat().st_mode & 0o777
            if mode & 0o077:
                os.chmod(config_path, mode & 0o600)
        return

    updated = yaml.safe_dump(config, sort_keys=False, default_flow_style=False).encode("utf-8")
    config_path.parent.mkdir(parents=True, exist_ok=True)
    mode = (config_path.stat().st_mode & 0o777) if original is not None else 0o600
    mode &= 0o600
    fd, tmp_name = tempfile.mkstemp(dir=config_path.parent, prefix=f".{config_path.name}.")
    try:
        with os.fdopen(fd, "wb") as tmp:
            tmp.write(updated)
            tmp.flush()
            os.fsync(tmp.fileno())
        os.chmod(tmp_name, mode)
        current = config_path.read_bytes() if config_path.exists() else None
        if current != original:
            raise RuntimeError("Hermes config changed during the update")
        os.replace(tmp_name, config_path)
    finally:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass


if __name__ == "__main__":
    try:
        main()
    except (KeyError, TypeError, ValueError, RuntimeError) as exc:
        raise SystemExit(f"Hermes preference update failed: {exc}") from None
