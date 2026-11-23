#!/usr/bin/env python3
"""Copy every skill from the tracked upstream repositories into the shared skill tree.

Upstream files are data: nothing from them runs. Use --check to report without writing.
Exit status: 0 when the tree is current, 1 when --check finds a change, 2 on an error.
"""

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SKILLS = Path("private_dot_agents/private_skills")
SOURCES = (
    {"repo": "janestreet/agent_skills", "branch": "master", "license": "MIT"},
)
LICENSE_FILES = ("LICENSE.md", "LICENSE", "LICENSE.txt")
SKILL_NAME = re.compile(r"[a-z0-9][a-z0-9-]*")
PART = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")
CHEZMOI_PREFIXES = ("after_", "before_", "create_", "dot_", "empty_", "encrypted_", "exact_",
                    "executable_", "external_", "literal_", "modify_", "once_", "onchange_",
                    "private_", "readonly_", "remove_", "run_", "symlink_")
MAX_FILE = 1024 * 1024
COMMIT = re.compile(r"[0-9a-f]{40}")


class SyncError(Exception):
    pass


def git(directory, *args):
    result = subprocess.run(["git", "-C", str(directory), *args], capture_output=True, check=False,
                            env={**os.environ, "GIT_TERMINAL_PROMPT": "0"})
    if result.returncode:
        raise SyncError(f"git {args[0]} failed: {result.stderr.decode(errors='replace').strip()}")
    return result.stdout


def safe_path(path):
    parts = path.split("/")
    for part in parts:
        if not PART.fullmatch(part) or part.startswith(CHEZMOI_PREFIXES) or part.startswith(".chezmoi"):
            return False
    return not path.endswith(".tmpl")


def frontmatter_with_upstream(text, name, source, commit):
    match = re.match(r"---\n(.*?\n)---\n", text, re.DOTALL)
    if not match:
        raise SyncError(f"{name}/SKILL.md has no YAML frontmatter")
    head = match.group(1)
    if re.search(r"(?m)^(license|metadata):", head):
        raise SyncError(f"{name}/SKILL.md already sets license or metadata; merge it by hand")
    url = f"https://github.com/{source['repo']}/blob/{source['branch']}/{name}/SKILL.md"
    extra = (f"license: {source['license']}\nmetadata:\n  upstream:\n    name: {name}\n"
             f"    url: {url}\n    commit: {commit}\n")
    return f"---\n{head}{extra}---\n{text[match.end():]}"


def upstream_skills(checkout, source):
    rows = git(checkout, "ls-tree", "-r", "-z", "--full-tree", "HEAD").decode().split("\0")
    entries = []
    for row in filter(None, rows):
        meta, path = row.split("\t", 1)
        mode, kind, blob = meta.split()
        entries.append((mode, kind, blob, path))
    names = sorted({path.split("/", 1)[0] for _, _, _, path in entries
                    if path.count("/") == 1 and path.endswith("/SKILL.md")})
    license_text = next((git(checkout, "cat-file", "blob", blob) for _, _, blob, path in entries
                         if path in LICENSE_FILES), None)
    if license_text is None:
        raise SyncError(f"{source['repo']} has no license file at its root")
    skills = {}
    for name in names:
        if not SKILL_NAME.fullmatch(name):
            raise SyncError(f"upstream skill name {name!r} is not a safe folder name")
        commit = git(checkout, "log", "-1", "--format=%H", "HEAD", "--", name).decode().strip()
        if not COMMIT.fullmatch(commit):
            raise SyncError(f"no commit found for {name}")
        files = {}
        for mode, kind, blob, path in entries:
            if not path.startswith(name + "/"):
                continue
            relative = path[len(name) + 1:]
            if kind != "blob" or mode != "100644":
                raise SyncError(f"{path} is not a regular non-executable file")
            if not safe_path(relative) or relative == "LICENSE.txt":
                raise SyncError(f"{path} has a name the skill tree cannot hold")
            data = git(checkout, "cat-file", "blob", blob)
            if len(data) > MAX_FILE:
                raise SyncError(f"{path} is larger than {MAX_FILE} bytes")
            files[relative] = data
        files["SKILL.md"] = frontmatter_with_upstream(
            files["SKILL.md"].decode(), name, source, commit).encode()
        files["LICENSE.txt"] = license_text
        skills[name] = {"commit": commit, "files": files}
    return skills


def local_files(folder):
    if not folder.is_dir():
        return {}
    files = {}
    for path in sorted(folder.rglob("*")):
        if path.is_symlink() or (path.exists() and not path.is_dir() and not path.is_file()):
            raise SyncError(f"{path} is not a regular file")
        if path.is_file():
            files[path.relative_to(folder).as_posix()] = path.read_bytes()
    return files


def pinned_commit(files):
    match = re.search(rb"(?m)^    commit: ([0-9a-f]{40})$", files.get("SKILL.md", b""))
    return match.group(1).decode() if match else None


def tracked_local_names(root, source):
    prefix = f"url: https://github.com/{source['repo']}/blob/"
    return {path.parent.name for path in (root / SKILLS).glob("*/SKILL.md")
            if prefix in path.read_text(encoding="utf-8")}


def compare(root, source, skills):
    changes = []
    for name, skill in skills.items():
        current = local_files(root / SKILLS / name)
        if current == skill["files"]:
            continue
        changes.append({
            "name": name, "state": "updated" if current else "new",
            "old": pinned_commit(current), "new": skill["commit"],
            "added": sorted(set(skill["files"]) - set(current)),
            "changed": sorted(path for path in set(skill["files"]) & set(current)
                              if skill["files"][path] != current[path]),
            "removed": sorted(set(current) - set(skill["files"])),
        })
    gone = sorted(tracked_local_names(root, source) - set(skills))
    return changes, gone


def write(root, skills, changes):
    for change in changes:
        folder = root / SKILLS / change["name"]
        files = skills[change["name"]]["files"]
        for relative in change["removed"]:
            (folder / relative).unlink()
        for relative in change["added"] + change["changed"]:
            target = folder / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(files[relative])
        for directory in sorted((p for p in folder.rglob("*") if p.is_dir()), reverse=True):
            if not any(directory.iterdir()):
                directory.rmdir()


def report(results):
    lines = ["# Upstream agent skills", ""]
    found = False
    for source, changes, gone in results:
        repo = source["repo"]
        lines.append(f"## [{repo}](https://github.com/{repo})")
        lines.append("")
        if not changes and not gone:
            lines += ["All skills are current.", ""]
            continue
        found = True
        for change in changes:
            link = (f"[{change['old'][:12]}...{change['new'][:12]}](https://github.com/{repo}/compare/"
                    f"{change['old']}...{change['new']})" if change["old"] else f"`{change['new'][:12]}`")
            lines.append(f"- `{change['name']}`: {change['state']}, {link}")
            for key in ("added", "changed", "removed"):
                if change[key]:
                    lines.append(f"  - {key}: " + ", ".join(f"`{path}`" for path in change[key]))
        for name in gone:
            lines.append(f"- `{name}`: removed upstream. Delete it by hand if you agree.")
        lines.append("")
    if found:
        lines += ["## Next steps", "",
                  "1. Review the upstream diff above for new tools, network calls, or scripts.",
                  "2. Run `python3 scripts/sync-upstream-skills.py` in the dotfiles repo.",
                  "3. For a new skill, add a case to `evals/skill-routing.json` and the list in "
                  "`docs/tooling-and-skills.md`.",
                  "4. Run `./tests/all`, then publish with `dotfiles-push` and a pull request.", ""]
    return "\n".join(lines), found


def clone(url, branch, directory):
    git(directory.parent, "clone", "--quiet", "--no-checkout", "--single-branch",
        "--branch", branch, "--", url, str(directory))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report changes and write nothing")
    parser.add_argument("--report", type=Path, help="also write the Markdown report to this file")
    parser.add_argument("--root", type=Path, default=ROOT, help=argparse.SUPPRESS)
    parser.add_argument("--clone-url", action="append", default=[], metavar="REPO=URL",
                        help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    overrides = dict(item.split("=", 1) for item in args.clone_url)
    results = []
    try:
        with tempfile.TemporaryDirectory(prefix="upstream-skills.") as work:
            for index, source in enumerate(SOURCES):
                checkout = Path(work) / str(index)
                url = overrides.get(source["repo"], f"https://github.com/{source['repo']}.git")
                clone(url, source["branch"], checkout)
                skills = upstream_skills(checkout, source)
                changes, gone = compare(args.root, source, skills)
                if changes and not args.check:
                    write(args.root, skills, changes)
                results.append((source, changes, gone))
    except SyncError as error:
        print(f"sync-upstream-skills: {error}", file=sys.stderr)
        return 2
    text, found = report(results)
    if args.report:
        args.report.write_text(text, encoding="utf-8")
    print(text)
    return 1 if found and args.check else 0


if __name__ == "__main__":
    sys.exit(main())
