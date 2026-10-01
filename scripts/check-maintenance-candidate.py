#!/usr/bin/env python3
"""Check routine pin changes using trusted code; pass only bounded data to the writer."""

import argparse
import base64
from datetime import datetime, timedelta, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tarfile
import tempfile
import tomllib
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("stable_release", ROOT / "dot_local/private_lib/chezmoi/stable-release-eligibility.py")
stable = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(stable)
TOOLS = ("neovim", "jj", "uv", "starship", "bun", "chezmoi")
PATHS = (".chezmoidata.toml", ".chezmoiversion.toml")
KEYS = ("linux_x86_64_sha256", "linux_arm64_sha256", "macos_x86_64_sha256", "macos_arm64_sha256")
SHA = re.compile(r"[0-9a-f]{64}")
COMMIT = re.compile(r"[0-9a-f]{40}")
REPOSITORY = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+")
MAX_BUNDLE = 65536  # Below both Actions job-output and Linux environment limits.
MAX_ARTIFACT = 256 * 1024 * 1024


def require(condition, message):
    if not condition:
        raise ValueError(message)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "duplicate JSON key")
        result[key] = value
    return result


def decode_json(data):
    require(len(data) <= MAX_BUNDLE, "candidate data exceeds the size limit")
    return json.loads(data, object_pairs_hook=unique_object)


def fields(value, expected):
    require(isinstance(value, dict) and set(value) == set(expected), "unexpected candidate fields")


def git(source, *args):
    result = subprocess.run(["git", "-C", str(source), *args], capture_output=True, check=False)
    require(result.returncode == 0, "Git source check failed")
    return result.stdout


def reference(source, value):
    require(isinstance(value, str) and COMMIT.fullmatch(value), "an exact commit SHA is required")
    require(git(source, "rev-parse", "--verify", value + "^{commit}").decode().strip() == value, "commit mismatch")
    return value


def committed_file(source, ref, path):
    row = git(source, "ls-tree", "-z", ref, "--", path).decode().rstrip("\0")
    require(row.startswith("100644 blob ") and row.endswith("\t" + path), "pin files must be existing regular non-executable files")
    return git(source, "show", f"{ref}:{path}")


def working_file(source, path):
    target = Path(source) / path
    mode = target.lstat().st_mode
    require(stat.S_ISREG(mode) and not mode & 0o111, "pin files must be regular non-executable files")
    return target.read_bytes()


def inventory():
    env = {**os.environ, "CHEZMOI_AUTOMATIC_UPDATES": "0"}
    result = subprocess.run(["bash", str(ROOT / "dot_local/bin/executable_chezmoi-bump"), "--inventory"],
                            env=env, capture_output=True, check=False)
    require(result.returncode == 0, "trusted dependency inventory failed")
    entries = json.loads(result.stdout)
    result = {entry["name"]: entry for entry in entries}
    require(len(entries) == len(result), "duplicate dependency contract")
    for name in TOOLS:
        require(name in result and result[name]["platforms"] == "4", "routine dependency contract is incomplete")
        require(REPOSITORY.fullmatch(result[name]["source"]), "routine dependency must use GitHub releases")
    return result


def exact_version(value, form):
    prefix = {"raw": "", "v": "v", "bun": "bun-v"}[form]
    require(isinstance(value, str) and value.startswith(prefix), "invalid version prefix")
    raw = value[len(prefix):]
    require(re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", raw), "an exact stable version is required")
    return stable.version(value)


def parse_pins(files, contracts):
    data = tomllib.loads(files[PATHS[0]].decode())
    versions = tomllib.loads(files[PATHS[1]].decode())["versions"]
    for name in TOOLS:
        pin = data["pinned"][name]
        exact_version(pin["version"], contracts[name]["versionFormat"])
        require(all(isinstance(pin[key], str) and SHA.fullmatch(pin[key]) for key in KEYS), "all four artifact checksums are required")
        if name != "chezmoi":
            require(versions.get(name) == pin["version"], "version files disagree")
    return data, versions


def replace_field(data, section, key, old, new):
    text = data.decode()
    section_pattern = re.compile(r"(?ms)^\[" + re.escape(section) + r"\]\r?\n(.*?)(?=^\[|\Z)")
    matches = list(section_pattern.finditer(text))
    require(len(matches) == 1, "missing or duplicate pin section")
    match = matches[0]
    body = match.group(1)
    pattern = re.compile(r'(?m)^(' + re.escape(key) + r'\s*=\s*")' + re.escape(old) + r'("[^\r\n]*)(\r?\n|$)')
    body, count = pattern.subn(lambda row: row[1] + new + row[2] + row[3], body)
    require(count == 1, "missing or duplicate pin field")
    return (text[:match.start(1)] + body + text[match.end(1):]).encode()


def routine_changes(before, after, contracts):
    old_data, old_versions = parse_pins(before, contracts)
    new_data, _ = parse_pins(after, contracts)
    expected = dict(before)
    changes = []
    for name in TOOLS:
        old, new = old_data["pinned"][name], new_data["pinned"][name]
        if new["version"] == old["version"]:
            continue
        form = contracts[name]["versionFormat"]
        old_v, new_v = exact_version(old["version"], form), exact_version(new["version"], form)
        require(new_v[:2] == old_v[:2] and new_v > old_v, "routine updates must increase only the patch version")
        for key in ("version", *KEYS):
            expected[PATHS[0]] = replace_field(expected[PATHS[0]], "pinned." + name, key, old[key], new[key])
        if name != "chezmoi":
            expected[PATHS[1]] = replace_field(expected[PATHS[1]], "versions", name, old_versions[name], new["version"])
        changes.append({"name": name, "current": old["version"], "target": new["version"]})
    require(expected == after, "candidate includes a change outside permitted version and checksum fields")
    return changes


def source_diff(source, base, head=None, routine=True):
    reference(source, base)
    if head:
        reference(source, head)
    paths = set(git(source, "diff", "--name-only", "-z", base, *([head] if head else [])).decode().rstrip("\0").split("\0")) - {""}
    if not head:
        require(not git(source, "ls-files", "--others", "--exclude-standard", "-z"), "untracked source files prevent publication")
    if routine:
        require(paths <= set(PATHS), "candidate changed a path outside the routine contract")
    before = {path: committed_file(source, base, path) for path in PATHS}
    after = {path: committed_file(source, head, path) if head else working_file(source, path) for path in PATHS}
    contracts = inventory()
    if routine:
        changes = routine_changes(before, after, contracts)
    else:
        parse_pins(after, contracts)
        changes = []
    return before, after, changes, contracts


class ArtifactRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, newurl):
        url = urllib.parse.urlsplit(newurl)
        require(url.scheme == "https" and url.hostname in (
            "github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"), "artifact redirect changed to an unapproved origin")
        return super().redirect_request(request, response, code, message, headers, newurl)


def artifact_digest(url):
    request = urllib.request.Request(url, headers={"User-Agent": "dotfiles-maintenance", "Cache-Control": "no-cache"})
    digest = hashlib.sha256()
    size = 0
    with urllib.request.build_opener(ArtifactRedirectHandler()).open(request, timeout=30) as response:
        while block := response.read(1024 * 1024):
            size += len(block)
            require(size <= MAX_ARTIFACT, "artifact exceeds download limit")
            digest.update(block)
    require(size > 0, "artifact is empty")
    return digest.hexdigest()


def install_jj(source, base, destination):
    """Install one hash-verified runner binary; never extract archive paths."""
    reference(source, base)
    pin = tomllib.loads(committed_file(source, base, PATHS[0]).decode())["pinned"]["jj"]
    exact_version(pin["version"], "v")
    platform = (os.environ.get("RUNNER_OS"), os.environ.get("RUNNER_ARCH"))
    index = {("Linux", "X64"): 0, ("Linux", "ARM64"): 1, ("macOS", "X64"): 2, ("macOS", "ARM64"): 3}[platform]
    expected = pin[KEYS[index]]
    require(isinstance(expected, str) and SHA.fullmatch(expected), "invalid runner jj checksum")
    require(Path(destination).is_absolute(), "runner tool path must be absolute")
    output = Path(destination).resolve()
    require(output.is_absolute() and not output.is_relative_to(Path(source).resolve()), "runner tools must be outside source")
    output.mkdir(parents=True, exist_ok=True)
    asset = stable.release_assets("jj", pin["version"])[index]
    url = f"https://github.com/jj-vcs/jj/releases/download/{pin['version']}/{asset}"
    digest, size = hashlib.sha256(), 0
    request = urllib.request.Request(url, headers={"User-Agent": "dotfiles-maintenance"})
    with tempfile.SpooledTemporaryFile(max_size=8 * 1024 * 1024, dir=output) as archive:
        with urllib.request.build_opener(ArtifactRedirectHandler()).open(request, timeout=30) as response:
            while block := response.read(1024 * 1024):
                size += len(block)
                require(size <= MAX_ARTIFACT, "runner artifact exceeds download limit")
                digest.update(block)
                archive.write(block)
        require(size > 0 and digest.hexdigest() == expected, "runner jj checksum mismatch")
        archive.seek(0)
        with tarfile.open(fileobj=archive, mode="r:gz") as package:
            members = [item for item in package.getmembers() if Path(item.name).name == "jj" and item.isfile()]
            require(len(members) == 1 and members[0].size <= MAX_ARTIFACT, "runner jj archive has an unexpected layout")
            temporary = output / ("jj.tmp." + str(os.getpid()))
            try:
                with package.extractfile(members[0]) as binary, temporary.open("xb") as executable:
                    while block := binary.read(1024 * 1024):
                        executable.write(block)
                temporary.chmod(0o755)
                temporary.replace(output / "jj")
            finally:
                temporary.unlink(missing_ok=True)


def release_records(changes, after, contracts):
    require(not os.environ.get("CHEZMOI_RELEASE_FIXTURE_DIR"), "routine validation requires fresh release metadata")
    now = datetime.now(timezone.utc)
    data = tomllib.loads(after[PATHS[0]].decode())
    records = []
    for change in changes:
        name, target = change["name"], change["target"]
        repo = contracts[name]["source"]
        tag = "v" + target if name == "chezmoi" else target
        rows = stable.github_rows(repo)
        matches = [row for row in rows if row.get("tag_name") == tag]
        require(len(matches) == 1, "exact release metadata is missing or ambiguous")
        row = matches[0]
        require(stable.select([row], change["current"], now, dependency=name, patch_only=True)[0] == "eligible", "release does not meet the seven-day stable patch policy")
        assets = {asset["name"]: asset for asset in row["assets"]}
        artifacts = []
        for key, asset_name in zip(KEYS, stable.release_assets(name, tag)):
            url = f"https://github.com/{repo}/releases/download/{tag}/{asset_name}"
            expected = data["pinned"][name][key]
            published_digest = assets[asset_name].get("digest")
            if isinstance(published_digest, str) and published_digest.startswith("sha256:"):
                actual = published_digest.removeprefix("sha256:")
            else:
                actual = artifact_digest(url)
            require(actual == expected, "artifact checksum does not match the exact release")
            artifacts.append({"name": asset_name, "url": url, "sha256": expected})
        records.append({**change, "publishedAt": row["published_at"], "artifacts": artifacts})
    return records


def identity(repository, base, run, attempt):
    require(isinstance(repository, str) and REPOSITORY.fullmatch(repository), "invalid repository identity")
    require(isinstance(base, str) and COMMIT.fullmatch(base), "invalid candidate base")
    for value in (run, attempt):
        require(isinstance(value, str) and re.fullmatch(r"[1-9]\d{0,19}", value), "invalid workflow run identity")


def build_bundle(source, base, repository, run, attempt, report):
    identity(repository, base, run, attempt)
    before, after, changes, contracts = source_diff(source, base)
    rows = decode_json(Path(report).read_bytes())
    fields(rows, ("schema", "dependencies"))
    require(type(rows["schema"]) is int and rows["schema"] == 1 and isinstance(rows["dependencies"], list), "invalid discovery report")
    checked = {}
    for row in rows["dependencies"]:
        fields(row, ("name", "source", "current", "state", "candidate"))
        require(row["name"] in contracts and row["name"] not in checked, "invalid discovery inventory")
        require(row["source"] == contracts[row["name"]]["source"], "discovery source mismatch")
        checked[row["name"]] = row
    old_data, _ = parse_pins(before, contracts)
    for name in TOOLS:
        require(name in checked and checked[name]["current"] == old_data["pinned"][name]["version"], "supported dependency scan is incomplete")
        require(checked[name]["state"] in ("eligible", "current", "too_new", "review"), "supported dependency scan failed")
    selected = {change["name"]: change for change in changes}
    for name in TOOLS:
        row = checked[name]
        if row["state"] == "eligible":
            target = row["candidate"]
            if contracts[name]["versionFormat"] == "raw":
                target = target.removeprefix("v")
            require(name in selected and selected[name]["target"] == target, "selected update was not applied")
        else:
            require(name not in selected, "unselected update was applied")
    files = [{"path": path, "beforeSha256": hashlib.sha256(before[path]).hexdigest(),
              "afterSha256": hashlib.sha256(after[path]).hexdigest(),
              "contents": base64.b64encode(after[path]).decode()} for path in PATHS if before[path] != after[path]]
    return {"schema": 1, "repository": repository, "base": base, "run": run, "attempt": attempt,
            "createdAt": datetime.now(timezone.utc).isoformat(), "files": files,
            "dependencies": release_records(changes, after, contracts)}


def validate_bundle(bundle, source, base, repository, run, attempt, online=False):
    identity(repository, base, run, attempt)
    fields(bundle, ("schema", "repository", "base", "run", "attempt", "createdAt", "files", "dependencies"))
    require(type(bundle["schema"]) is int and bundle["schema"] == 1, "unsupported candidate schema")
    require((bundle["repository"], bundle["base"], bundle["run"], bundle["attempt"]) == (repository, base, run, attempt), "candidate workflow or source identity mismatch")
    now = datetime.now(timezone.utc)
    created = stable.published(bundle["createdAt"])
    require(now - timedelta(hours=24) <= created <= now, "candidate is stale or from the future")
    before, _, _, contracts = source_diff(source, base)
    require(not git(source, "diff", "--name-only", base), "publisher checkout must match the trusted base")
    after = dict(before)
    require(isinstance(bundle["files"], list) and len(bundle["files"]) <= len(PATHS), "invalid candidate file count")
    seen = set()
    for item in bundle["files"]:
        fields(item, ("path", "beforeSha256", "afterSha256", "contents"))
        path = item["path"]
        require(isinstance(path, str) and path in PATHS and path not in seen, "candidate path is not permitted or is duplicated")
        seen.add(path)
        require(item["beforeSha256"] == hashlib.sha256(before[path]).hexdigest(), "candidate base content mismatch")
        require(isinstance(item["contents"], str), "invalid candidate contents")
        contents = base64.b64decode(item["contents"], validate=True)
        require(contents != before[path] and item["afterSha256"] == hashlib.sha256(contents).hexdigest(), "candidate content hash mismatch")
        after[path] = contents
    changes = routine_changes(before, after, contracts)
    require(isinstance(bundle["dependencies"], list) and len(bundle["dependencies"]) == len(changes), "candidate release records mismatch")
    data = tomllib.loads(after[PATHS[0]].decode())
    for change, record in zip(changes, bundle["dependencies"]):
        fields(record, ("name", "current", "target", "publishedAt", "artifacts"))
        require(all(record[key] == value for key, value in change.items()), "candidate release identity mismatch")
        require(stable.published(record["publishedAt"]) <= now - timedelta(days=7), "candidate release is too new")
        name, target = change["name"], change["target"]
        tag = "v" + target if name == "chezmoi" else target
        require(isinstance(record["artifacts"], list) and len(record["artifacts"]) == 4, "candidate platform scope is incomplete")
        for key, asset_name, artifact in zip(KEYS, stable.release_assets(name, tag), record["artifacts"]):
            fields(artifact, ("name", "url", "sha256"))
            require(artifact == {"name": asset_name, "url": f"https://github.com/{contracts[name]['source']}/releases/download/{tag}/{asset_name}",
                                  "sha256": data["pinned"][name][key]}, "candidate artifact identity mismatch")
    if online:
        require(release_records(changes, after, contracts) == bundle["dependencies"], "fresh release metadata disagrees with candidate")
    return after, changes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("build", "validate", "diff", "install-jj"))
    parser.add_argument("--source", default=".")
    parser.add_argument("--base", required=True)
    parser.add_argument("--head")
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY"))
    parser.add_argument("--run", default=os.environ.get("GITHUB_RUN_ID"))
    parser.add_argument("--attempt", default=os.environ.get("GITHUB_RUN_ATTEMPT"))
    parser.add_argument("--report")
    parser.add_argument("--output")
    parser.add_argument("--bundle")
    parser.add_argument("--online", action="store_true")
    parser.add_argument("--routine", action="store_true")
    parser.add_argument("--materialize", action="store_true")
    parser.add_argument("--destination")
    args = parser.parse_args()
    try:
        if args.operation == "install-jj":
            require(args.destination, "install-jj requires --destination")
            install_jj(args.source, args.base, args.destination)
            print("Installed verified runner jj.")
        elif args.operation == "build":
            require(args.report and args.output, "build requires --report and --output")
            bundle = build_bundle(args.source, args.base, args.repository, args.run, args.attempt, args.report)
            data = json.dumps(bundle, separators=(",", ":")).encode()
            require(len(data) <= MAX_BUNDLE, "candidate data exceeds the size limit")
            Path(args.output).write_bytes(data)
            print(f"Prepared {len(bundle['dependencies'])} verified patch update(s).")
        elif args.operation == "validate":
            raw = Path(args.bundle).read_bytes() if args.bundle else base64.b64decode(os.environ.get("MAINTENANCE_CANDIDATE", ""), validate=True)
            after, changes = validate_bundle(decode_json(raw), args.source, args.base, args.repository, args.run, args.attempt, args.online)
            if args.materialize:
                for path in PATHS:
                    if working_file(args.source, path) != after[path]:
                        (Path(args.source) / path).write_bytes(after[path])
            print(f"Validated {len(changes)} patch update(s).")
        else:
            _, after, changes, contracts = source_diff(args.source, args.base, args.head, args.routine)
            if args.routine:
                require(changes, "routine pull request has no patch changes")
                if args.online:
                    release_records(changes, after, contracts)
            print("Dependency policy passed.")
        return 0
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError, tarfile.TarError) as error:
        print(f"Maintenance candidate rejected: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
