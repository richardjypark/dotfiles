import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

def main():
    root, state = map(Path, sys.argv[1:])
    lock = root / "package-lock.json"
    if lock.is_symlink():
        raise SystemExit(0)
    original = subprocess.check_output(["git", "-C", str(root), "show", "HEAD:package-lock.json"])
    current = lock.read_bytes()
    try:
        expected = json.loads(original)
        actual = json.loads(current)
    except (ValueError, UnicodeError):
        raise SystemExit(0)
    legacy = copy.deepcopy(expected)
    for name, package in legacy.get("packages", {}).items():
        if name.startswith("node_modules/@esbuild/") and package.get("peer") is True:
            package.pop("peer")
    if legacy == expected or actual != legacy:
        raise SystemExit(0)

    # Keep the original local bytes outside the checkout before replacing them.
    state.mkdir(parents=True, exist_ok=True)
    fd, backup = tempfile.mkstemp(prefix="hermes-package-lock-", suffix=".json", dir=state)
    with os.fdopen(fd, "wb") as out:
        out.write(current)
        out.flush()
        os.fsync(out.fileno())
    fd, replacement = tempfile.mkstemp(prefix=".package-lock-", dir=root)
    try:
        with os.fdopen(fd, "wb") as out:
            out.write(original)
        os.chmod(replacement, lock.stat().st_mode & 0o777)
        if lock.read_bytes() != current:
            raise SystemExit("Hermes lockfile changed during repair; leaving it untouched.")
        os.replace(replacement, lock)
    finally:
        if os.path.exists(replacement):
            os.unlink(replacement)
    print(f"Repaired legacy Hermes npm metadata; backup: {backup}")


if __name__ == "__main__":
    main()
