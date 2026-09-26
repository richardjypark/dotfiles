#!/usr/bin/env python3
"""Reject private source paths and personal email metadata before publication."""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys


NOREPLY = re.compile(r"(?:[^\s@]+@users\.noreply\.github\.com|noreply@github\.com)", re.I)
OID = re.compile(r"[0-9a-f]{40}(?:[0-9a-f]{24})?")


def git(root, *args, data=None, allowed=(0,)):
    result = subprocess.run(["git", "-C", str(root), *args], input=data, capture_output=True)
    if result.returncode not in allowed:
        raise ValueError(f"Git {args[0]} failed; the public-file check did not complete")
    return result.stdout


def ignored_paths(root, paths):
    paths = sorted(set(paths))
    if not paths:
        return []
    result = git(root, "check-ignore", "--no-index", "-z", "--stdin",
                 data=b"\0".join(paths) + b"\0", allowed=(0, 1))
    return [path for path in result.split(b"\0") if path]


def outgoing_commits(root, remote, heads):
    remotes = git(root, "remote").decode().splitlines()
    if remote not in remotes:
        raise ValueError("Use a configured remote; fetch its references before publication")
    return git(root, "rev-list", *heads, "--not", f"--remotes={remote}").decode().splitlines()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default=".")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--base", help="check commits after this base through --head")
    group.add_argument("--remote", help="check --head commits absent from this remote's local refs")
    group.add_argument("--pre-push", metavar="REMOTE", help="read Git pre-push records from stdin")
    parser.add_argument("--head", default="HEAD")
    args = parser.parse_args()
    try:
        root = Path(git(args.source, "rev-parse", "--show-toplevel").decode().strip())
        paths = git(root, "ls-files", "--cached", "-z").split(b"\0")
        commits = []
        if args.pre_push:
            heads = []
            for line in sys.stdin:
                fields = line.split()
                if len(fields) != 4 or not OID.fullmatch(fields[1]) or not OID.fullmatch(fields[3]):
                    raise ValueError("Invalid Git pre-push record")
                if fields[1].strip("0"):
                    heads.append(fields[1])
            if heads:
                commits = outgoing_commits(root, args.pre_push, heads)
        elif args.remote or args.base:
            head = git(root, "rev-parse", "--verify", f"{args.head}^{{commit}}").decode().strip()
            if args.remote:
                commits = outgoing_commits(root, args.remote, [head])
            else:
                base = git(root, "rev-parse", "--verify", f"{args.base}^{{commit}}").decode().strip()
                commits = git(root, "rev-list", f"{base}..{head}").decode().splitlines()

        failures = []
        for path in ignored_paths(root, [path for path in paths if path]):
            failures.append("Tracked private/ignored path: " + json.dumps(path.decode(errors="replace")))
        for commit in commits:
            tree = git(root, "ls-tree", "-r", "--name-only", "-z", commit).split(b"\0")
            for path in ignored_paths(root, [path for path in tree if path]):
                failures.append(f"Commit {commit[:12]} contains a private/ignored path: "
                                + json.dumps(path.decode(errors="replace")))
            emails = git(root, "show", "-s", "--format=%ae%x00%ce", commit).decode().strip().split("\0")
            if len(emails) != 2 or any(not NOREPLY.fullmatch(email) for email in emails):
                failures.append(f"Commit {commit[:12]} needs GitHub no-reply author and committer emails")
        if failures:
            print("\n".join(sorted(set(failures))), file=sys.stderr)
            return 1
        print(f"Public-file check passed ({len(commits)} outgoing commits checked).")
        return 0
    except (OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
