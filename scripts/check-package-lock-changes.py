#!/usr/bin/env python3
"""Check changed npm lock entries with trusted code; read the candidate only as Git data."""

import argparse
import base64
from datetime import datetime, timezone
import html
import http.client
import json
from pathlib import PurePosixPath
import re
import subprocess
import sys
import urllib.parse
import urllib.request

REGISTRY = "https://registry.npmjs.org"
LOCKFILES = ("package-lock.json", "npm-shrinkwrap.json")
MIN_AGE_DAYS = 3  # The host default, CHEZMOI_NPM_MIN_VERSION_AGE_DAYS in npm.sh.
MAX_LOCKFILE = 16 * 1024 * 1024
MAX_PACKUMENT = 64 * 1024 * 1024
MAX_CHANGED = 1000
FIELDS = ("version", "resolved", "integrity", "link")
COMMIT = re.compile(r"[0-9a-f]{40}")
NAME = re.compile(r"(?:@[a-z0-9][a-z0-9._~-]*/)?[A-Za-z0-9][A-Za-z0-9._~-]*")
PATH_NAME = re.compile(r"(?:^|/)node_modules/((?:@[^/]+/)?[^/]+)$")
VERSION = re.compile(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?")
INTEGRITY = re.compile(r"sha(256|512)-([A-Za-z0-9+/]+={0,2})")
TIMESTAMP = re.compile(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?(?:Z|[+-]\d\d:\d\d)")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "duplicate JSON key")
        result[key] = value
    return result


def git(source, *args):
    result = subprocess.run(["git", "-C", str(source), *args], capture_output=True, check=False)
    require(result.returncode == 0, f"git {args[0]} failed")
    return result.stdout


def changed_lockfiles(source, base, head):
    paths = git(source, "diff", "--name-only", "--no-renames", "-z", base, head).decode().split("\0")
    return sorted(path for path in paths if PurePosixPath(path).name in LOCKFILES)


def read_lock(source, ref, path):
    """Return the packages map at ref, or None when the file does not exist there."""
    row = git(source, "ls-tree", "-l", "-z", ref, "--", path).decode().rstrip("\0")
    if not row:
        return None
    meta, _, name = row.partition("\t")
    mode, kind, _, size = meta.split()
    require(mode == "100644" and kind == "blob" and name == path, f"{path} must be a regular file")
    require(int(size) <= MAX_LOCKFILE, f"{path} exceeds the size limit")
    lock = json.loads(git(source, "show", f"{ref}:{path}"), object_pairs_hook=unique_object)
    require(isinstance(lock, dict) and lock.get("lockfileVersion") in (2, 3), f"{path} needs lockfileVersion 2 or 3")
    require(isinstance(lock.get("packages"), dict), f"{path} has no packages map")
    return lock["packages"]


def loose_name(key, meta):
    name = meta.get("name")
    match = PATH_NAME.search(key)
    return name if isinstance(name, str) and name else (match.group(1) if match else None)


def package_name(key, meta):
    name = meta.get("name")
    if not isinstance(name, str) or not name:
        match = PATH_NAME.search(key)
        name = match.group(1) if match else ""
    require(NAME.fullmatch(name), f"{key}: invalid package name")
    return name


def tarball_url(name, version):
    return f"{REGISTRY}/{name}/-/{name.rsplit('/', 1)[-1]}-{version}.tgz"


def check_entry(key, meta):
    """Apply the offline rules that hosts use for automatic installs."""
    require(isinstance(meta, dict), f"{key}: invalid lock entry")
    require(not meta.get("link"), f"{key}: linked packages are not allowed")
    name = package_name(key, meta)
    version = meta.get("version")
    require(isinstance(version, str) and VERSION.fullmatch(version), f"{key}: an exact version is required")
    require(meta.get("resolved") == tarball_url(name, version), f"{key}: resolved must be the public registry tarball")
    value = meta.get("integrity")
    integrity = INTEGRITY.fullmatch(value) if isinstance(value, str) else None
    require(integrity, f"{key}: SHA-256 or SHA-512 integrity is required")
    digest = base64.b64decode(integrity[2], validate=True)
    require(len(digest) * 8 == int(integrity[1]) and base64.b64encode(digest).decode() == integrity[2],
            f"{key}: malformed integrity")
    return name, version


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        raise ValueError("registry redirects are not allowed")


def fetch_packument(name):
    request = urllib.request.Request(f"{REGISTRY}/{urllib.parse.quote(name, safe='@')}", headers={
        "Accept": "application/json", "Cache-Control": "no-cache", "User-Agent": "dotfiles-npm-lock-check"})
    with urllib.request.build_opener(NoRedirect()).open(request, timeout=30) as response:
        data = response.read(MAX_PACKUMENT + 1)
    require(len(data) <= MAX_PACKUMENT, f"registry metadata for {name} exceeds the size limit")
    document = json.loads(data)
    require(isinstance(document, dict) and isinstance(document.get("versions"), dict)
            and isinstance(document.get("time"), dict), f"invalid registry metadata for {name}")
    return document


def publisher(manifest):
    user = manifest.get("_npmUser")
    return user.get("name") if isinstance(user, dict) else None


def verify_online(name, version, meta, old, document, now, notes):
    """Compare the entry with the registry, apply the host age rule and add review notes."""
    manifest = document["versions"].get(version)
    require(isinstance(manifest, dict), f"{name}@{version} is not on the public registry")
    dist = manifest.get("dist") if isinstance(manifest.get("dist"), dict) else {}
    require(dist.get("integrity") == meta["integrity"], f"{name}@{version}: integrity differs from the registry")
    require(dist.get("tarball") == meta["resolved"], f"{name}@{version}: tarball differs from the registry")
    stamp = document["time"].get(version)
    require(isinstance(stamp, str) and TIMESTAMP.fullmatch(stamp), f"{name}@{version} has no valid publish time")
    published = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
    require(published <= now, f"{name}@{version} has a publish time in the future")
    age = (now - published).total_seconds() / 86400
    require(age >= MIN_AGE_DAYS, f"{name}@{version} is {age:.1f} days old; the host minimum is {MIN_AGE_DAYS} days")
    previous = document["versions"].get(old.get("version")) if old else None
    if isinstance(previous, dict):
        if publisher(previous) != publisher(manifest):
            notes.append(f"publisher {publisher(previous)} -> {publisher(manifest)}")
        previous_dist = previous.get("dist") if isinstance(previous.get("dist"), dict) else {}
        if previous_dist.get("attestations") and not dist.get("attestations"):
            notes.append("provenance lost")
    return age


def review_lockfile(path, before, after, *, online, now, fetch=fetch_packument, cache=None):
    """Return (rows, failures) for the changed entries of one lockfile."""
    cache = {} if cache is None else cache
    known = {loose_name(key, meta) for key, meta in before.items() if key and isinstance(meta, dict)}
    changed = [(key, meta) for key, meta in after.items() if key and not (
        isinstance(before.get(key), dict) and isinstance(meta, dict)
        and all(before[key].get(field) == meta.get(field) for field in FIELDS))]
    require(len(changed) <= MAX_CHANGED, f"{path} changes more than {MAX_CHANGED} entries")
    rows, failures = [], []
    for key, meta in changed:
        old = before.get(key) if isinstance(before.get(key), dict) else None
        try:
            name, version = check_entry(key, meta)
            notes = []
            if name not in known:
                notes.append("new package")
            if meta.get("hasInstallScript") and not (old or {}).get("hasInstallScript"):
                notes.append("install script")
            if meta.get("bin") and not (old or {}).get("bin"):
                notes.append("new bin")
            age = None
            if online:
                if name not in cache:
                    cache[name] = fetch(name)
                age = verify_online(name, version, meta, old, cache[name], now, notes)
        except (ValueError, KeyError, TypeError, OSError, http.client.HTTPException) as error:
            failures.append(f"{path}: {error}")
            continue
        rows.append({"lockfile": path, "package": name, "old": (old or {}).get("version") or "-", "new": version,
                     "age": "-" if age is None else f"{age:.1f}", "notes": ", ".join(notes) or "-"})
    return rows, failures


def markdown(rows, failures):
    def cell(value):
        return html.escape(str(value)).replace("|", "\\|")

    lines = ["### npm lockfile changes", ""]
    if rows:
        lines += ["| Lockfile | Package | Change | Age (days) | Review notes |", "| --- | --- | --- | --- | --- |"]
        lines += [f"| {cell(r['lockfile'])} | {cell(r['package'])} | {cell(r['old'] + ' -> ' + r['new'])} "
                  f"| {cell(r['age'])} | {cell(r['notes'])} |" for r in rows]
    lines += [f"- Rejected: {cell(failure)}" for failure in failures]
    if not rows and not failures:
        lines.append("No npm lockfile changes.")
    return "\n".join(lines) + "\n\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default=".")
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--online", action="store_true", help="compare entries with the public registry")
    parser.add_argument("--summary", help="append a Markdown report to this file")
    args = parser.parse_args()
    rows, failures = [], []
    try:
        for ref in (args.base, args.head):
            require(COMMIT.fullmatch(ref) and git(args.source, "rev-parse", "--verify", ref + "^{commit}").decode().strip() == ref,
                    "exact commit SHAs are required")
        cache, now = {}, datetime.now(timezone.utc)
        for path in changed_lockfiles(args.source, args.base, args.head):
            after = read_lock(args.source, args.head, path)
            if after is None:
                continue
            found = review_lockfile(path, read_lock(args.source, args.base, path) or {}, after,
                                    online=args.online, now=now, cache=cache)
            rows += found[0]
            failures += found[1]
    except (OSError, ValueError, KeyError, TypeError) as error:
        failures.append(str(error))
    for row in rows:
        print(f"{row['lockfile']}: {row['package']} {row['old']} -> {row['new']} (age {row['age']} days; notes: {row['notes']})")
    if args.summary:
        with open(args.summary, "a", encoding="utf-8") as handle:
            handle.write(markdown(rows, failures))
    for failure in failures:
        print(f"npm lock policy rejected: {failure}", file=sys.stderr)
    if failures:
        return 1
    print("npm lock policy passed." if rows else "No npm lockfile changes.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
