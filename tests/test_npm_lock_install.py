#!/usr/bin/env python3
"""Verify installed versions and atomic, integrity-checked shrinkwrap repairs."""

import base64
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tarfile
import unittest
from unittest.mock import patch

from lib.temp import temporary_directory

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("npm_lock_install", ROOT / "dot_local/private_lib/chezmoi/npm-lock-install.py")
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)


class InstalledLockTest(unittest.TestCase):
    def setUp(self):
        self.project = Path(self.enterContext(temporary_directory()))
        self.relative = "node_modules/pi/node_modules/brace-expansion"
        self.destination = self.project / self.relative
        self.destination.mkdir(parents=True)
        (self.destination / "package.json").write_text(json.dumps({"name": "brace-expansion", "version": "5.0.9"}))
        (self.project / "node_modules/pi/package.json").write_text(json.dumps({"name": "pi", "version": "1.0.0"}))
        self.metadata = {"version": "5.0.12", "resolved": "https://registry.npmjs.org/brace-expansion/-/brace-expansion-5.0.12.tgz"}
        self.packages = {"": {}, "node_modules/pi": {"version": "1.0.0", "hasShrinkwrap": True}, self.relative: self.metadata}
        self.archive = self.make_archive()
        self.write_lock()

    def make_archive(self, name="brace-expansion", version="5.0.12", unsafe=None):
        data = io.BytesIO()
        with tarfile.open(fileobj=data, mode="w:gz") as archive:
            content = json.dumps({"name": name, "version": version}).encode()
            member = tarfile.TarInfo("package/package.json")
            member.size = len(content)
            archive.addfile(member, io.BytesIO(content))
            if unsafe:
                member = tarfile.TarInfo(unsafe)
                member.type = tarfile.SYMTYPE
                member.linkname = "../../outside"
                archive.addfile(member)
        result = data.getvalue()
        self.metadata["integrity"] = "sha512-" + base64.b64encode(hashlib.sha512(result).digest()).decode()
        return result

    def write_lock(self):
        (self.project / "package-lock.json").write_text(json.dumps({"lockfileVersion": 3, "packages": self.packages}))

    def actual_version(self):
        return json.loads((self.destination / "package.json").read_text())["version"]

    def repair(self):
        with patch.dict(os.environ, {"TRUST_ON_FIRST_USE_INSTALLERS": "1"}), \
                patch.object(installer.urllib.request, "urlopen", return_value=io.BytesIO(self.archive)):
            installer.verify(self.project, repair=True)

    def test_outer_lock_does_not_hide_a_stale_installed_version(self):
        with self.assertRaisesRegex(ValueError, "5.0.9 != 5.0.12"):
            installer.verify(self.project)
        self.assertEqual(self.actual_version(), "5.0.9")

    def test_verified_repair_and_repeat_without_network(self):
        self.repair()
        self.assertEqual(self.actual_version(), "5.0.12")
        with patch.object(installer.urllib.request, "urlopen", side_effect=AssertionError("unexpected download")):
            installer.verify(self.project, repair=True)

    def test_download_still_requires_trust(self):
        with patch.dict(os.environ, {"TRUST_ON_FIRST_USE_INSTALLERS": "0"}), \
                self.assertRaisesRegex(ValueError, "explicit installer trust"):
            installer.verify(self.project, repair=True)
        self.assertEqual(self.actual_version(), "5.0.9")

    def test_bad_integrity_preserves_installed_package(self):
        self.archive += b"corruption"
        with self.assertRaisesRegex(ValueError, "integrity mismatch"):
            self.repair()
        self.assertEqual(self.actual_version(), "5.0.9")

    def test_wrong_manifest_preserves_installed_package(self):
        for name, version in (("other", "5.0.12"), ("brace-expansion", "5.0.9")):
            with self.subTest(name=name, version=version):
                self.archive = self.make_archive(name=name, version=version)
                self.write_lock()
                with self.assertRaisesRegex(ValueError, "manifest mismatch"):
                    self.repair()
                self.assertEqual(self.actual_version(), "5.0.9")

    def test_unsafe_archive_preserves_installed_package(self):
        for name in ("../outside", "package/../../outside", "package/link"):
            with self.subTest(name=name):
                self.archive = self.make_archive(unsafe=name)
                self.write_lock()
                with self.assertRaisesRegex(ValueError, "unsafe locked package archive"):
                    self.repair()
                self.assertEqual(self.actual_version(), "5.0.9")

    def test_failed_replacement_restores_installed_package(self):
        rename = Path.rename

        def fail_candidate(path, target):
            if path.name == "package":
                raise OSError("fixture replacement failure")
            return rename(path, target)

        with patch.object(Path, "rename", fail_candidate), self.assertRaisesRegex(OSError, "replacement failure"):
            self.repair()
        self.assertEqual(self.actual_version(), "5.0.9")

    def test_mismatch_without_published_shrinkwrap_is_not_repaired(self):
        self.packages["node_modules/pi"].pop("hasShrinkwrap")
        self.write_lock()
        with self.assertRaisesRegex(ValueError, "installed npm version differs"):
            self.repair()

    def test_missing_required_packages_and_build_dependencies_fail(self):
        self.repair()
        self.packages["node_modules/missing"] = {"version": "1.0.0"}
        self.write_lock()
        with self.assertRaisesRegex(ValueError, "required locked npm package is missing"):
            installer.verify(self.project)
        self.packages["node_modules/missing"]["dev"] = True
        self.write_lock()
        installer.verify(self.project)
        with self.assertRaisesRegex(ValueError, "required locked npm package is missing"):
            installer.verify(self.project, include_dev=True)
        self.packages["node_modules/missing"]["optional"] = True
        self.write_lock()
        installer.verify(self.project, include_dev=True)

    def test_private_registry_and_unlocked_integrity_are_refused(self):
        for key, value in (("resolved", "https://private.invalid/package.tgz"), ("integrity", "")):
            with self.subTest(key=key):
                saved = self.metadata[key]
                self.metadata[key] = value
                self.write_lock()
                with self.assertRaisesRegex(ValueError, "repair requires"):
                    self.repair()
                self.metadata[key] = saved


if __name__ == "__main__":
    unittest.main()
