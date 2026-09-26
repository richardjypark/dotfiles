#!/usr/bin/env python3
"""Select an exact stable release from complete, fresh publication metadata."""

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

VERSION = re.compile(r"^(?:rust-v|bun-v|v)?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
STAMP = re.compile(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?(?:Z|[+-](?:[01]\d|2[0-3]):[0-5]\d)$")


class MetadataRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, newurl):
        origin = urllib.parse.urlsplit(request.full_url)
        destination = urllib.parse.urlsplit(newurl)
        if destination.scheme != "https" or destination.netloc != origin.netloc:
            raise ValueError("release metadata redirect changed origin")
        return super().redirect_request(request, response, code, message, headers, newurl)


def version(value):
    match = VERSION.fullmatch(value)
    return tuple(map(int, match.groups())) if match else None


def published(value):
    if not isinstance(value, str) or not STAMP.fullmatch(value):
        raise ValueError("missing or invalid publication time")
    result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    return result.astimezone(timezone.utc)


def risk(current, candidate):
    old, new = version(current), version(candidate)
    if old is None or new is None:
        raise ValueError("invalid semantic version")
    if new <= old:
        return "current"
    if new[0] != old[0] or (old[0] == 0 and new[1] != old[1]):
        return "major_review"
    return "eligible"


def release_assets(dependency, tag):
    raw = tag.removeprefix("bun-v").removeprefix("v")
    names = {
        "neovim": ("nvim-linux-x86_64.tar.gz", "nvim-linux-arm64.tar.gz", "nvim-macos-x86_64.tar.gz", "nvim-macos-arm64.tar.gz"),
        "jj": tuple(f"jj-{tag}-{platform}.tar.gz" for platform in (
            "x86_64-unknown-linux-musl", "aarch64-unknown-linux-musl",
            "x86_64-apple-darwin", "aarch64-apple-darwin")),
        "uv": tuple(f"uv-{platform}.tar.gz" for platform in (
            "x86_64-unknown-linux-gnu", "aarch64-unknown-linux-gnu",
            "x86_64-apple-darwin", "aarch64-apple-darwin")),
        "starship": tuple(f"starship-{platform}.tar.gz" for platform in (
            "x86_64-unknown-linux-musl", "aarch64-unknown-linux-musl",
            "x86_64-apple-darwin", "aarch64-apple-darwin")),
        "bun": ("bun-linux-x64.zip", "bun-linux-aarch64.zip", "bun-darwin-x64.zip", "bun-darwin-aarch64.zip"),
        "chezmoi": tuple(f"chezmoi_{raw}_{platform}.tar.gz" for platform in (
            "linux_amd64", "linux_arm64", "darwin_amd64", "darwin_arm64")),
    }
    if dependency not in names:
        raise ValueError("unsupported artifact dependency")
    return names[dependency]


def select(rows, current, now, days=7, required_assets=(), dependency=None):
    current_version = version(current)
    if current_version is None or days < 0:
        raise ValueError("invalid release policy")
    if not isinstance(rows, list) or not rows:
        raise ValueError("empty release metadata")
    candidates = []
    too_new = False
    incomplete = False
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("invalid release metadata")
        if row.get("draft") or row.get("prerelease"):
            continue
        tag = row.get("tag_name")
        parsed = version(tag) if isinstance(tag, str) else None
        if parsed is None:
            continue
        stamp = published(row.get("published_at"))
        if stamp > now:
            raise ValueError("future release time")
        if parsed <= current_version:
            continue
        if stamp > now - timedelta(days=days):
            too_new = True
            continue
        assets = row.get("assets", [])
        if not isinstance(assets, list):
            raise ValueError("invalid release assets")
        names = {a.get("name") for a in assets if isinstance(a, dict)}
        expected = release_assets(dependency, tag) if dependency else required_assets
        if not set(expected).issubset(names):
            incomplete = True
            continue
        candidates.append((parsed, tag))
    if candidates:
        tag = max(candidates)[1]
        return risk(current, tag), tag
    if incomplete:
        return "unsupported", "missing required assets"
    return ("too_new" if too_new else "current"), ""


def fetch_json(url):
    fixture = os.environ.get("CHEZMOI_RELEASE_FIXTURE_DIR")
    if fixture:
        if os.environ.get("CHEZMOI_AUTOMATIC_UPDATES") == "1":
            raise ValueError("automatic mode cannot use release fixtures")
        match = re.search(r"/releases\?per_page=100&page=(\d+)$", url)
        path = os.path.join(fixture, f"page-{match.group(1)}.json") if match else os.path.join(fixture, "npm.json")
        with open(path, encoding="utf-8") as stream:
            return json.load(stream)
    origin = urllib.parse.urlsplit(url)
    if origin.scheme != "https" or origin.netloc not in ("api.github.com", "registry.npmjs.org"):
        raise ValueError("unsupported release metadata origin")
    headers = {"Accept": "application/json", "User-Agent": "chezmoi-stable-release", "Cache-Control": "no-cache"}
    if origin.netloc == "api.github.com":
        headers["Accept"] = "application/vnd.github+json"
    request = urllib.request.Request(url, headers=headers)
    if origin.netloc == "api.github.com" and os.environ.get("GITHUB_TOKEN"):
        # urllib does not copy this header when it follows a redirect.
        request.add_unredirected_header("Authorization", "Bearer " + os.environ["GITHUB_TOKEN"])
    with urllib.request.build_opener(MetadataRedirectHandler()).open(request, timeout=20) as response:
        return json.load(response)


def github_rows(repo, cap=10):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo):
        raise ValueError("invalid GitHub repository")
    rows = []
    for page in range(1, cap + 1):
        batch = fetch_json(f"https://api.github.com/repos/{repo}/releases?per_page=100&page={page}")
        if not isinstance(batch, list):
            raise ValueError("invalid GitHub response")
        rows.extend(batch)
        if len(batch) < 100:
            return rows
    raise ValueError("release pagination cap reached")


def npm_rows(package):
    registry = "https://registry.npmjs.org"
    for setting in ("CHEZMOI_NPM_REGISTRY", "NPM_CONFIG_REGISTRY", "npm_config_registry"):
        if os.environ.get(setting, registry).rstrip("/") != registry:
            raise ValueError("automatic mode requires public npm metadata")
    data = fetch_json(registry + "/" + urllib.parse.quote(package, safe=""))
    if not isinstance(data, dict) or not isinstance(data.get("time"), dict) or not isinstance(data.get("versions"), dict):
        raise ValueError("missing npm version or time metadata")
    rows = []
    for key, metadata in data["versions"].items():
        if not version(key):
            continue
        if not isinstance(metadata, dict):
            raise ValueError("invalid npm version metadata")
        stamp = data["time"].get(key)
        published(stamp)
        rows.append({"tag_name": key, "published_at": stamp})
    if not rows:
        raise ValueError("no published stable npm versions")
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("current")
    parser.add_argument("--days", type=int, default=7)
    parser.add_argument("--now")
    parser.add_argument("--asset", action="append", default=[])
    parser.add_argument("--dependency")
    args = parser.parse_args()
    if os.environ.get("CHEZMOI_AUTOMATIC_UPDATES") == "1" and (args.now or os.environ.get("CHEZMOI_RELEASE_FIXTURE_DIR")):
        parser.error("automatic mode requires the real clock and fresh release metadata")
    if args.days < 0:
        parser.error("release age cannot be negative")
    if args.days != 7 and os.environ.get("CHEZMOI_AUTOMATIC_UPDATES") == "1":
        parser.error("automatic mode requires seven days")
    if version(args.current) is None:
        parser.error("invalid current version")
    now = published(args.now) if args.now else datetime.now(timezone.utc)
    try:
        rows = npm_rows(args.source[4:]) if args.source.startswith("npm:") else github_rows(args.source)
        state, candidate = select(rows, args.current, now, args.days, args.asset, args.dependency)
    except (OSError, ValueError, json.JSONDecodeError, urllib.error.URLError) as exc:
        print(f"error\t{exc}")
        return 2
    print(f"{state}\t{candidate}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
