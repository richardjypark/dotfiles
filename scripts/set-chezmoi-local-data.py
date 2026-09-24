#!/usr/bin/env python3
"""Set machine-local role and profile in the active chezmoi config."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def active_config_path():
    data = json.loads(subprocess.check_output(["chezmoi", "data", "--format=json"], text=True))
    return Path(data["chezmoi"]["configFile"])


def update_toml(content, values):
    lines = content.splitlines(keepends=True)
    section_start = None
    section_end = len(lines)
    for index, line in enumerate(lines):
        match = re.match(r"^\s*\[([^\]]+)\]\s*(?:#.*)?$", line)
        if not match:
            continue
        if section_start is not None:
            section_end = index
            break
        if match.group(1).strip() == "data":
            section_start = index + 1

    if section_start is None:
        if lines and not lines[-1].endswith("\n"):
            lines[-1] += "\n"
        lines.extend(["\n[data]\n"])
        section_start = len(lines)
        section_end = len(lines)

    for key, value in values.items():
        replacement = f"{key} = {json.dumps(value)}\n"
        found = False
        for index in range(section_start, section_end):
            if re.match(rf"^\s*{re.escape(key)}\s*=", lines[index]):
                lines[index] = replacement
                found = True
                break
        if not found:
            lines.insert(section_end, replacement)
            section_end += 1
    return "".join(lines)


def update_structured(content, values, fmt):
    if fmt == ".json":
        config = json.loads(content) if content.strip() else {}
        dump = lambda value: json.dumps(value, indent=2, ensure_ascii=False) + "\n"
    else:
        try:
            import yaml
        except ImportError as exc:
            raise RuntimeError("PyYAML is required to update an active YAML chezmoi config") from exc
        config = yaml.safe_load(content) if content.strip() else {}
        dump = lambda value: yaml.safe_dump(value, sort_keys=False)
    if not isinstance(config, dict):
        raise RuntimeError("chezmoi config must contain a mapping")
    data = config.setdefault("data", {})
    if not isinstance(data, dict):
        raise RuntimeError("chezmoi config data must be a mapping")
    if all(data.get(key) == value for key, value in values.items()):
        return content
    data.update(values)
    return dump(config)


def write_atomic(path, old_bytes, new_bytes):
    if new_bytes == old_bytes:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = (path.stat().st_mode & 0o777) if path.exists() else 0o600
    mode &= 0o600
    fd, tmp_name = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(new_bytes)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(tmp_name, mode)
        if path.exists() and path.read_bytes() != old_bytes:
            raise RuntimeError("chezmoi config changed during the update")
        os.replace(tmp_name, path)
    finally:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--role", choices=("workstation", "server"), required=True)
    parser.add_argument("--profile", choices=("standard", "omarchy"), required=True)
    args = parser.parse_args()
    path = active_config_path()
    if path.suffix not in (".toml", ".json", ".yaml", ".yml"):
        raise SystemExit(f"Unsupported chezmoi config format: {path.suffix}")
    if path.is_symlink():
        raise SystemExit("Refusing to replace a symlinked chezmoi config")
    old_bytes = path.read_bytes() if path.exists() else b""
    existed = path.exists()
    values = {"role": args.role, "profile": args.profile}
    content = old_bytes.decode("utf-8")
    updated = update_toml(content, values) if path.suffix == ".toml" else update_structured(content, values, path.suffix)
    write_atomic(path, old_bytes, updated.encode("utf-8"))
    try:
        subprocess.check_call(["chezmoi", "data", "--format=json"], stdout=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        if existed:
            write_atomic(path, updated.encode("utf-8"), old_bytes)
        else:
            path.unlink()
        raise


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, UnicodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
