#!/usr/bin/env python3
"""Decide whether a Dependabot pull request may merge automatically, then apply it.

The job that runs this script checks out the trusted default branch. It reads
the pull request head only as Git data and never runs code from it. A pull
request is eligible only when all of these hold:

- Dependabot opened it from this repository against the default branch, and
  every commit is a verified Dependabot commit or a GitHub "Update branch"
  merge of the default branch;
- it changes only the OpenRouter agent npm manifest and lockfile or the Go CI
  tool module files;
- each changed direct dependency is a patch or minor update (for 0.x versions,
  a patch update), with no added, removed or downgraded dependency;
- the default branch requires the Linux, macOS, secret and dependency checks
  with base freshness, so GitHub merges only after all of them pass.
"""

import argparse
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys

SPEC = importlib.util.spec_from_file_location("publisher", Path(__file__).with_name("publish-maintenance-candidate.py"))
publisher = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(publisher)
candidate = publisher.candidate
require = candidate.require

BOT = "dependabot[bot]"
COMMITTER = "web-flow"
NPM_MANIFEST = "dot_local/share/openrouter-agent/package.json"
GO_MANIFEST = ".github/tools/go.mod"
LOCKFILES = {"dot_local/share/openrouter-agent/package-lock.json", ".github/tools/go.sum"}
ALLOWED = {NPM_MANIFEST, GO_MANIFEST} | LOCKFILES
NPM_SECTIONS = ("dependencies", "devDependencies", "optionalDependencies", "peerDependencies", "overrides")
VERSION = re.compile(r"v?(\d+)\.(\d+)\.(\d+)([-+][0-9A-Za-z.+-]*)?")
OPERATOR = re.compile(r"[\^~=]?")
GO_REQUIRE = re.compile(r"(\S+)\s+(v\S+)(\s*//\s*indirect)?")


def check_version(name, old, new):
    """Allow only an increase that keeps the major (and the minor for 0.x) version."""
    old_op, new_op = OPERATOR.match(old).group(), OPERATOR.match(new).group()
    require(old_op == new_op, f"{name}: the range operator changed ({old} -> {new})")
    old_match, new_match = VERSION.fullmatch(old[len(old_op):]), VERSION.fullmatch(new[len(new_op):])
    require(old_match and new_match, f"{name}: {old} -> {new} is not a plain version change")
    before = tuple(int(part) for part in old_match.groups()[:3])
    after = tuple(int(part) for part in new_match.groups()[:3])
    require(before[0] == after[0], f"{name}: major update {old} -> {new}")
    require(before[0] != 0 or before[1] == after[1], f"{name}: 0.x minor update {old} -> {new}")
    require(after > before, f"{name}: {old} -> {new} is a downgrade or a pre-release change")


def npm_changes(old_text, new_text):
    old, new = json.loads(old_text), json.loads(new_text)
    require(isinstance(old, dict) and isinstance(new, dict), "package.json is not an object")
    rest = lambda data: {key: value for key, value in data.items() if key not in NPM_SECTIONS}
    require(rest(old) == rest(new), "package.json changes outside the dependency versions")
    changes = []
    for section in NPM_SECTIONS:
        before, after = old.get(section, {}), new.get(section, {})
        require(isinstance(before, dict) and isinstance(after, dict), f"package.json {section} is not an object")
        require(before.keys() == after.keys(), f"package.json {section}: a dependency was added or removed")
        for name, value in before.items():
            if value != after[name]:
                require(isinstance(value, str) and isinstance(after[name], str), f"{name}: nested override change")
                changes.append((name, value, after[name]))
    return changes


def go_requires(text):
    """Return the require entries and every other line of a go.mod file."""
    requires, other, block = {}, [], False
    for line in text.splitlines():
        stripped = line.strip()
        if block:
            if stripped == ")":
                block = False
                continue
            entry = stripped
        elif stripped == "require (":
            block = True
            continue
        elif stripped.startswith("require "):
            entry = stripped[len("require "):].strip()
        else:
            other.append(line)
            continue
        # Any comment other than the indirect marker fails the match: review it by hand.
        match = GO_REQUIRE.fullmatch(entry)
        require(match, f"go.mod: unexpected require line: {line.strip()}")
        require(match[1] not in requires, f"go.mod: duplicate requirement {match[1]}")
        requires[match[1]] = (match[2], bool(match[3]))
    require(not block, "go.mod: unterminated require block")
    return requires, other


def go_changes(old_text, new_text):
    (before, old_other), (after, new_other) = go_requires(old_text), go_requires(new_text)
    require(old_other == new_other, "go.mod changes outside the require versions")
    require(before.keys() == after.keys(), "go.mod: a module was added or removed")
    changes = []
    for module, (version, indirect) in before.items():
        require(after[module][1] == indirect, f"{module}: the indirect marker changed")
        if after[module][0] != version:
            changes.append((module, version, after[module][0]))
    return changes


def check_pull_request(pr, repository, branch, head):
    require(pr["state"] == "open" and not pr["draft"], "the pull request is not open and ready")
    require(pr["user"]["login"] == BOT, "the pull request author is not Dependabot")
    require((pr["head"]["repo"] or {}).get("full_name") == repository, "the head branch is not in this repository")
    require(pr["base"]["ref"] == branch, "the pull request does not target the default branch")
    require(pr["head"]["sha"] == head, "the pull request head moved; a new run decides")


def check_commits(commits, on_default_branch):
    """Accept verified Dependabot commits and GitHub "Update branch" merges of the default branch.

    The strict required checks make a pull request that falls behind the default
    branch unmergeable until someone with write access updates it. That merge
    brings in only default-branch commits; the diff rules still check every
    change that the pull request makes against its merge base.
    """
    require(0 < len(commits) < 100, "unexpected commit count")
    dependabot = 0
    for commit in commits:
        sha = commit["sha"][:12]
        require((commit.get("committer") or {}).get("login") == COMMITTER, f"commit {sha} was not committed by GitHub")
        require(commit["commit"]["verification"].get("verified") is True, f"commit {sha} has no verified signature")
        if (commit.get("author") or {}).get("login") == BOT:
            dependabot += 1
            continue
        parents = [parent["sha"] for parent in commit.get("parents", [])]
        require(len(parents) == 2 and on_default_branch(parents[1]),
                f"commit {sha} is neither a Dependabot commit nor a merge of the default branch")
    require(dependabot, "the pull request has no Dependabot commit")


def is_ancestor(source, commit, base):
    return subprocess.run(["git", "-C", str(source), "merge-base", "--is-ancestor", commit, base],
                          capture_output=True, check=False).returncode == 0


def changed_files(source, base, head):
    output = candidate.git(source, "diff", "--name-only", "--no-renames", base, head).decode()
    files = set(output.split())
    require(files, "the pull request changes no files")
    require(files <= ALLOWED, "files outside the auto-merge scope: " + ", ".join(sorted(files - ALLOWED)))
    require(files & {NPM_MANIFEST, GO_MANIFEST}, "no direct dependency changed; lockfile-only updates need review")
    return files


def evaluate(source, repository, branch, pr, commits, base, head):
    """Return the direct version changes, or raise ValueError with the reason to refuse."""
    check_pull_request(pr, repository, branch, head)
    check_commits(commits, lambda commit: is_ancestor(source, commit, base))
    merge_base = candidate.git(source, "merge-base", base, head).decode().strip()
    files = changed_files(source, merge_base, head)
    changes = []
    for path, parse in ((NPM_MANIFEST, npm_changes), (GO_MANIFEST, go_changes)):
        if path in files:
            old = candidate.git(source, "show", f"{merge_base}:{path}").decode()
            new = candidate.git(source, "show", f"{head}:{path}").decode()
            changes += parse(old, new)
    require(changes, "no direct dependency version changed")
    for name, old, new in changes:
        check_version(name, old, new)
    return changes


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--source", default=".")
    parser.add_argument("--repository", required=True)
    parser.add_argument("--number", required=True, type=int)
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--summary")
    args = parser.parse_args()
    require(candidate.REPOSITORY.fullmatch(args.repository), "invalid repository")
    require(candidate.COMMIT.fullmatch(args.base) and candidate.COMMIT.fullmatch(args.head), "invalid commit")

    branch, _ = publisher.default_state(args.source, args.repository)
    pr = publisher.api(args.source, f"repos/{args.repository}/pulls/{args.number}")
    commits = publisher.api(args.source, f"repos/{args.repository}/pulls/{args.number}/commits?per_page=100")
    try:
        changes = evaluate(args.source, args.repository, branch, pr, commits, args.base, args.head)
        publisher.require_merge_rules(args.source, args.repository, branch)
        eligible, reason = True, ""
    except ValueError as error:
        eligible, reason = False, str(error)

    lines = ["## Dependabot auto-merge", ""]
    if eligible:
        lines += ["Eligible. GitHub merges it after every required check passes.", "",
                  "| Dependency | From | To |", "| --- | --- | --- |"]
        lines += [f"| {name} | {old} | {new} |" for name, old, new in changes]
    else:
        lines.append(f"Not eligible: {reason}. Review and merge it by hand.")
    print("\n".join(lines))
    if args.summary:
        with open(args.summary, "a", encoding="utf-8") as summary:
            summary.write("\n".join(lines) + "\n")

    if args.apply:
        command = ["gh", "pr", "merge", str(args.number), "--repo", args.repository]
        if eligible:
            publisher.run(args.source, *command, "--auto", "--merge", "--match-head-commit", args.head)
        elif pr.get("auto_merge"):
            publisher.run(args.source, *command, "--disable-auto")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ValueError as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
