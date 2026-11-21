#!/usr/bin/env python3
"""Count code comments in repo-authored scripts and hold each file to a baseline.

The baseline in tests/comment-baseline.tsv only goes down. See docs/adr/0001-no-code-comments.md.

  comment-ratchet.py --check            fail if a file has more or fewer comment lines than its baseline
  comment-ratchet.py --update           lower the baseline to the current counts; refuse any increase
  comment-ratchet.py --list [PATH...]   print each counted comment line as path:line: text
  comment-ratchet.py --total            print the total counted comment lines
"""

from __future__ import annotations

import argparse
import fnmatch
import io
import re
import subprocess
import sys
import tokenize
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "tests/comment-baseline.tsv"

INCLUDE = (
    ".chezmoiscripts/*",
    ".githooks/*",
    "bootstrap-vps.sh",
    "autoresearch.checks.sh",
    "dot_local/bin/*",
    "dot_local/private_lib/*",
    "dot_local/share/openrouter-agent/src/*",
    "dot_local/share/openrouter-agent/test/*",
    "dot_local/share/pi-maintenance-agent/bin/*",
    "dot_local/share/pi-maintenance-agent/tests/*",
    "dot_pi/agent/extensions/*",
    "private_dot_claude/executable_*",
    "scripts/*",
    "tests/*",
)
EXCLUDE = (
    "*.example",
    "*.md",
    "dot_pi/agent/extensions/subagent/*",
)

PRAGMA = re.compile(
    r"^(#!|#\s*(shellcheck|noqa|type:|pyright:|pragma|-\*-)|//\s*(@ts-|eslint-|biome-)|///\s*<reference)"
)
HEREDOC = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")


def language(path: str, text: str) -> str | None:
    name = path.rsplit("/", 1)[-1]
    if name.endswith(".ts"):
        return "ts"
    if name.endswith(".py"):
        return "py"
    if name.endswith((".sh", ".sh.tmpl", ".bash")):
        return "sh"
    if "." in name.removeprefix("executable_").lstrip("."):
        return None
    first = text.split("\n", 1)[0]
    if first.startswith("#!"):
        if "python" in first:
            return "py"
        if re.search(r"\b(ba|z)?sh\b", first):
            return "sh"
    return None


def exempt(path: str, comment: str) -> bool:
    return bool(PRAGMA.match(comment)) or (path.endswith(".tmpl") and "{{" in comment)


def shell_comments(lines: list[str]) -> list[tuple[int, str]]:
    found: list[tuple[int, str]] = []
    terminator: str | None = None
    for number, line in enumerate(lines, 1):
        if terminator is not None:
            if line.strip() == terminator:
                terminator = None
            continue
        stripped = line.lstrip()
        if stripped.startswith("#"):
            found.append((number, stripped))
        else:
            single = double = False
            for index, char in enumerate(line):
                if char == "'" and not double:
                    single = not single
                elif char == '"' and not single and (index == 0 or line[index - 1] != "\\"):
                    double = not double
                elif char == "#" and not single and not double and index and line[index - 1] in " \t":
                    found.append((number, line[index:]))
                    break
        match = HEREDOC.search(line.split(" #", 1)[0])
        if match and "<<<" not in line:
            terminator = match.group(2)
    return found


def python_comments(text: str) -> list[tuple[int, str]]:
    try:
        return [(token.start[0], token.string) for token in tokenize.generate_tokens(io.StringIO(text).readline)
                if token.type == tokenize.COMMENT]
    except (tokenize.TokenError, SyntaxError):
        return []


def typescript_comments(lines: list[str]) -> list[tuple[int, str]]:
    found: list[tuple[int, str]] = []
    in_block = False
    for number, line in enumerate(lines, 1):
        stripped = line.strip()
        if in_block:
            found.append((number, stripped))
            in_block = "*/" not in stripped
            continue
        if stripped.startswith("/*"):
            found.append((number, stripped))
            in_block = "*/" not in stripped[2:]
        elif stripped.startswith("//"):
            found.append((number, stripped))
        else:
            match = re.search(r"[;,{}()\[\]]\s+//\s", line)
            if match:
                found.append((number, line[match.start() + 1:].strip()))
    return found


def comments(path: str, text: str) -> list[tuple[int, str]]:
    kind = language(path, text)
    if kind == "py":
        found = python_comments(text)
    elif kind == "sh":
        found = shell_comments(text.splitlines())
    elif kind == "ts":
        found = typescript_comments(text.splitlines())
    else:
        return []
    return [(number, comment) for number, comment in found
            if not (number == 1 and comment.startswith("#!")) and not exempt(path, comment)]


def in_scope(path: str) -> bool:
    return (any(fnmatch.fnmatch(path, pattern) for pattern in INCLUDE)
            and not any(fnmatch.fnmatch(path, pattern) for pattern in EXCLUDE))


def tracked_files() -> list[str]:
    output = subprocess.run(["git", "-C", str(ROOT), "ls-files", "--cached", "--others", "--exclude-standard"],
                            capture_output=True, text=True, check=True).stdout
    return sorted(path for path in set(output.splitlines()) if in_scope(path) and (ROOT / path).is_file())


def counts() -> dict[str, int]:
    result = {}
    for path in tracked_files():
        try:
            text = (ROOT / path).read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        found = comments(path, text)
        if found:
            result[path] = len(found)
    return result


def read_baseline() -> dict[str, int]:
    if not BASELINE.exists():
        return {}
    baseline = {}
    for line in BASELINE.read_text().splitlines():
        if line and not line.startswith("#"):
            count, path = line.split("\t", 1)
            baseline[path] = int(count)
    return baseline


def write_baseline(values: dict[str, int]) -> None:
    body = "".join(f"{values[path]}\t{path}\n" for path in sorted(values) if values[path])
    BASELINE.write_text("# Allowed comment lines per file. Only lower these; see scripts/comment-ratchet.py.\n" + body)


def check() -> int:
    current, baseline = counts(), read_baseline()
    over = {path: (count, baseline.get(path, 0)) for path, count in current.items() if count > baseline.get(path, 0)}
    under = {path: (current.get(path, 0), allowed) for path, allowed in baseline.items()
             if current.get(path, 0) < allowed}
    for path, (count, allowed) in sorted(over.items()):
        print(f"{path}: {count} comment lines, baseline allows {allowed}. Delete the new comment; "
              "put a decision in docs/adr/ and other text in names or tests.")
    for path, (count, allowed) in sorted(under.items()):
        print(f"{path}: {count} comment lines, below the baseline of {allowed}. "
              "Run scripts/comment-ratchet.py --update to lock in the reduction.")
    total = sum(current.values())
    print(f"comment lines: {total} (baseline {sum(baseline.values())})")
    return 1 if over or under else 0


def update() -> int:
    current, baseline = counts(), read_baseline()
    increased = sorted(path for path, count in current.items() if count > baseline.get(path, 0))
    if increased and baseline:
        for path in increased:
            print(f"refused: {path} has {current[path]} comment lines, baseline {baseline.get(path, 0)}")
        return 1
    write_baseline(current)
    print(f"baseline: {sum(current.values())} comment lines in {len(current)} files")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true")
    group.add_argument("--update", action="store_true")
    group.add_argument("--list", nargs="*", metavar="PATH")
    group.add_argument("--total", action="store_true")
    args = parser.parse_args()
    if args.check:
        return check()
    if args.update:
        return update()
    if args.total:
        print(sum(counts().values()))
        return 0
    paths = args.list or tracked_files()
    for path in paths:
        if not in_scope(path):
            continue
        text = (ROOT / path).read_text(encoding="utf-8")
        for number, comment in comments(path, text):
            print(f"{path}:{number}: {comment}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
