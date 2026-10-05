#!/usr/bin/env python3
"""Check the npm lockfile change policy: registry tarballs, integrity, age and review notes."""

import base64
from datetime import datetime, timedelta, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import unittest

from lib.temp import temporary_directory

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/check-package-lock-changes.py"
SPEC = importlib.util.spec_from_file_location("package_lock_changes", SCRIPT)
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)
NOW = datetime(2026, 10, 5, 12, tzinfo=timezone.utc)


def integrity(seed):
    return "sha512-" + base64.b64encode(hashlib.sha512(seed.encode()).digest()).decode()


def entry(name, version, **extra):
    return {"version": version, "resolved": checker.tarball_url(name, version),
            "integrity": integrity(f"{name}@{version}"), **extra}


def release(name, version, days_old, publisher="maintainer", provenance=True):
    dist = {"integrity": integrity(f"{name}@{version}"), "tarball": checker.tarball_url(name, version)}
    if provenance:
        dist["attestations"] = {"url": "https://registry.npmjs.org/-/npm/v1/attestations/example"}
    return version, {"version": version, "dist": dist, "_npmUser": {"name": publisher}}, \
        (NOW - timedelta(days=days_old)).isoformat().replace("+00:00", "Z")


def registry(packages):
    return {name: {"versions": {version: manifest for version, manifest, _ in rows},
                   "time": {version: stamp for version, _, stamp in rows}}
            for name, rows in packages.items()}.__getitem__


def no_registry(name):
    raise AssertionError(f"unexpected registry request for {name}")


class ReviewTest(unittest.TestCase):
    def review(self, before, after, fetch=no_registry, online=True):
        return checker.review_lockfile("app/package-lock.json", before, after, online=online, now=NOW, fetch=fetch)

    def test_unchanged_entries_need_no_registry(self):
        packages = {"": {"name": "app"}, "node_modules/demo": entry("demo", "1.0.0")}
        self.assertEqual(self.review(packages, dict(packages)), ([], []))

    def test_mature_update_passes_with_publisher_and_provenance_notes(self):
        fetch = registry({"demo": [release("demo", "1.0.0", 40, "alice"), release("demo", "1.1.0", 10, "bob", provenance=False)]})
        rows, failures = self.review({"node_modules/demo": entry("demo", "1.0.0")},
                                     {"node_modules/demo": entry("demo", "1.1.0")}, fetch)
        self.assertEqual(failures, [])
        self.assertEqual([(row["old"], row["new"], row["age"], row["notes"]) for row in rows],
                         [("1.0.0", "1.1.0", "10.0", "publisher alice -> bob, provenance lost")])

    def test_registry_mismatch_young_and_future_releases_fail(self):
        fetch = registry({"swapped": [release("swapped", "2.0.0", 30)], "young": [release("young", "1.0.1", 1)],
                          "future": [release("future", "3.0.0", -1)]})
        after = {"node_modules/swapped": {**entry("swapped", "2.0.0"), "integrity": integrity("other")},
                 "node_modules/young": entry("young", "1.0.1"), "node_modules/future": entry("future", "3.0.0")}
        rows, failures = self.review({}, after, fetch)
        self.assertEqual(rows, [])
        self.assertEqual(len(failures), 3)
        self.assertIn("swapped@2.0.0: integrity differs from the registry", failures[0])
        self.assertIn("young@1.0.1 is 1.0 days old; the host minimum is 3 days", failures[1])
        self.assertIn("future@3.0.0 has a publish time in the future", failures[2])

    def test_offline_rules_reject_unsafe_entries_without_registry_requests(self):
        demo = entry("demo", "1.0.0")
        after = {
            "node_modules/other-host": {**demo, "resolved": "https://example.com/demo/-/demo-1.0.0.tgz"},
            "node_modules/git-source": {**demo, "resolved": "git+https://github.com/example/demo.git"},
            "node_modules/weak-hash": {**entry("weak-hash", "1.0.0"), "integrity": "sha1-" + base64.b64encode(b"x" * 20).decode()},
            "node_modules/no-hash": {"version": "1.0.0", "resolved": checker.tarball_url("no-hash", "1.0.0")},
            "node_modules/range": {**entry("range", "1.0.0"), "version": "^1.0.0"},
            "packages/local": {"resolved": "packages/local", "link": True},
        }
        rows, failures = self.review({}, after)
        self.assertEqual(rows, [])
        self.assertEqual([failure.split(": ", 2)[1] for failure in failures],
                         ["node_modules/other-host", "node_modules/git-source", "node_modules/weak-hash",
                          "node_modules/no-hash", "node_modules/range", "packages/local"])

    def test_new_package_notes_install_script_and_bin_offline(self):
        rows, failures = self.review({}, {"node_modules/tool": entry("tool", "1.0.0", hasInstallScript=True, bin={"tool": "cli.js"})},
                                     online=False)
        self.assertEqual(failures, [])
        self.assertEqual(rows[0]["notes"], "new package, install script, new bin")
        self.assertEqual(rows[0]["age"], "-")

    def test_scoped_names_use_the_scoped_tarball_path(self):
        fetch = registry({"@scope/pkg": [release("@scope/pkg", "1.2.3", 8)]})
        rows, failures = self.review({}, {"node_modules/@scope/pkg": entry("@scope/pkg", "1.2.3")}, fetch)
        self.assertEqual(failures, [])
        self.assertEqual(checker.tarball_url("@scope/pkg", "1.2.3"), "https://registry.npmjs.org/@scope/pkg/-/pkg-1.2.3.tgz")
        self.assertEqual(rows[0]["package"], "@scope/pkg")

    def test_minimum_age_matches_the_host_default(self):
        npm_helpers = (ROOT / "dot_local/private_lib/chezmoi/npm.sh").read_text()
        default = re.search(r'value="\$\{CHEZMOI_NPM_MIN_VERSION_AGE_DAYS:-(\d+)\}"', npm_helpers)
        self.assertIsNotNone(default)
        self.assertEqual(int(default.group(1)), checker.MIN_AGE_DAYS)


class CommandTest(unittest.TestCase):
    def setUp(self):
        self.repo = Path(self.enterContext(temporary_directory()))
        self.env = {**os.environ, "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1",
                    "GIT_AUTHOR_NAME": "test", "GIT_COMMITTER_NAME": "test",
                    "GIT_AUTHOR_EMAIL": "test@users.noreply.github.com", "GIT_COMMITTER_EMAIL": "test@users.noreply.github.com"}
        self.git("init", "-q", "-b", "main")
        self.base = self.commit({"node_modules/demo": entry("demo", "1.0.0")})

    def git(self, *args):
        result = subprocess.run(["git", "-C", str(self.repo), *args], env=self.env, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def commit(self, packages, raw=None, path="app/package-lock.json"):
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(raw or json.dumps({"lockfileVersion": 3, "packages": {"": {"name": "app"}, **packages}}, indent=2))
        self.git("add", "--all")
        self.git("commit", "-qm", "test: lockfile")
        return self.git("rev-parse", "HEAD")

    def run_check(self, head, *extra):
        return subprocess.run([sys.executable, str(SCRIPT), "--source", str(self.repo), "--base", self.base, "--head", head, *extra],
                              env=self.env, capture_output=True, text=True, timeout=60)

    def test_command_reads_changed_lockfiles_from_git(self):
        bad = self.commit({"node_modules/demo": {**entry("demo", "1.0.1"), "resolved": "https://example.com/demo-1.0.1.tgz"}})
        result = self.run_check(bad)
        self.assertEqual(result.returncode, 1)
        self.assertIn("node_modules/demo: resolved must be the public registry tarball", result.stderr)

        good = self.commit({"node_modules/demo": entry("demo", "1.0.1")})
        summary = self.repo / "summary.md"
        result = self.run_check(good, "--summary", str(summary))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("npm lock policy passed.", result.stdout)
        self.assertIn("| app/package-lock.json | demo | 1.0.0 -&gt; 1.0.1 | - | - |", summary.read_text())

    def test_command_rejects_duplicate_json_keys(self):
        lock = json.dumps({"lockfileVersion": 3, "packages": {"node_modules/demo": entry("demo", "1.0.0")}})
        duplicate = self.commit({}, raw=lock[:-1] + ', "packages": {}}')
        result = self.run_check(duplicate)
        self.assertEqual(result.returncode, 1)
        self.assertIn("duplicate JSON key", result.stderr)

    def test_command_ignores_changes_without_lockfiles(self):
        (self.repo / "README.md").write_text("docs\n")
        self.git("add", "README.md")
        self.git("commit", "-qm", "docs: readme")
        result = self.run_check(self.git("rev-parse", "HEAD"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("No npm lockfile changes.", result.stdout)


if __name__ == "__main__":
    unittest.main()
