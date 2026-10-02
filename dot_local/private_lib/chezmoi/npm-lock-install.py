#!/usr/bin/env python3
"""Check installed npm versions; repair published shrinkwrap conflicts from SRI pins."""

import argparse
import base64
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import tarfile
import tempfile
import urllib.parse
import urllib.request


def repair_package(project, relative, metadata):
    if os.environ.get("TRUST_ON_FIRST_USE_INSTALLERS") != "1":
        raise ValueError("locked dependency repair requires explicit installer trust")
    name = metadata.get("name") or relative.rsplit("node_modules/", 1)[-1]
    version = metadata["version"]
    url = urllib.parse.urlsplit(metadata.get("resolved", ""))
    expected_path = f"/{name}/-/{name.rsplit('/', 1)[-1]}-{version}.tgz"
    if (url.scheme != "https" or url.netloc != "registry.npmjs.org"
            or urllib.parse.unquote(url.path) != expected_path or url.query or url.fragment):
        raise ValueError(f"repair requires an exact public registry tarball: {relative}")
    integrity = re.fullmatch(r"sha(256|512)-([A-Za-z0-9+/]+={0,2})", metadata.get("integrity", ""))
    if not integrity:
        raise ValueError(f"repair requires locked SHA integrity: {relative}")
    with urllib.request.urlopen(url.geturl(), timeout=30) as response:
        archive = response.read(64 * 1024 * 1024 + 1)
    digest = base64.b64encode(hashlib.new("sha" + integrity[1], archive).digest()).decode()
    if len(archive) > 64 * 1024 * 1024 or digest != integrity[2]:
        raise ValueError(f"locked tarball integrity mismatch: {relative}")
    destination = project / relative
    if destination.is_symlink() or not destination.resolve().is_relative_to(project):
        raise ValueError(f"installed package escapes the project: {relative}")
    with tempfile.TemporaryDirectory(prefix=".chezmoi-npm-repair-", dir=destination.parent) as temporary:
        stage = Path(temporary)
        with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as package:
            for member in package.getmembers():
                path = PurePosixPath(member.name)
                if (not path.parts or path.parts[0] != "package" or ".." in path.parts
                        or not (member.isfile() or member.isdir())):
                    raise ValueError(f"unsafe locked package archive: {relative}")
            package.extractall(stage, filter="data")
        manifest = json.loads((stage / "package/package.json").read_text())
        if manifest.get("name") != name or manifest.get("version") != version:
            raise ValueError(f"locked tarball manifest mismatch: {relative}")
        previous = stage / "previous"
        destination.rename(previous)
        try:
            (stage / "package").rename(destination)
        except BaseException:
            previous.rename(destination)
            raise
    print(f"Repaired locked npm dependency: {name}@{version}")


def verify(project, include_dev=False, repair=False):
    project = Path(project).resolve()
    lock = json.loads((project / "package-lock.json").read_text())
    packages = lock["packages"]
    for relative, metadata in packages.items():
        if not relative or metadata.get("link") or (metadata.get("dev") and not include_dev):
            continue
        path = PurePosixPath(relative)
        if path.is_absolute() or ".." in path.parts or not relative.startswith("node_modules/"):
            raise ValueError("invalid installed package path")
        manifest = project / relative / "package.json"
        if not manifest.is_file():
            if metadata.get("optional"):
                continue
            raise ValueError(f"required locked npm package is missing: {relative}")
        actual = json.loads(manifest.read_text()).get("version")
        if actual == metadata["version"]:
            continue
        shrinkwrapped = any(metadata.get("hasShrinkwrap") for parent, metadata in packages.items()
                            if parent and relative.startswith(parent + "/node_modules/"))
        if not repair or not shrinkwrapped:
            raise ValueError(f"installed npm version differs from lock: {relative}: {actual} != {metadata['version']}")
        repair_package(project, relative, metadata)
    if repair:
        verify(project, include_dev=include_dev)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project")
    parser.add_argument("--include-dev", action="store_true")
    parser.add_argument("--repair", action="store_true")
    args = parser.parse_args()
    try:
        verify(args.project, args.include_dev, args.repair)
    except (OSError, ValueError, KeyError, tarfile.TarError) as error:
        parser.exit(1, f"npm lock verification failed: {error}\n")


if __name__ == "__main__":
    main()
