#!/usr/bin/env python3
"""A failed mktemp must stop shell tests without deleting any directory."""

import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "tests/lib/temp.sh"
# Shell test entry points that create temporary directories.
SHELL_TESTS = (
    "tests/all",
    "tests/syntax",
    "tests/lint-shell",
    "tests/test-cz-maintenance.sh",
    "tests/test-chezmoi-update-helpers.sh",
    "tests/test-cz-wrappers.sh",
    "tests/test-mise-migration.sh",
    "tests/test-syntax-startup.sh",
)


def run_in(directory, command, **env):
    return subprocess.run(command, cwd=directory, env={**os.environ, **env},
                          capture_output=True, text=True, timeout=120)


class TempSafetyTest(unittest.TestCase):
    def test_failed_mktemp_stops_without_touching_the_caller_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory) / "work"
            work.mkdir()
            (work / "canary").write_text("keep\n")
            shim = Path(directory) / "bin"
            shim.mkdir()
            (shim / "mktemp").write_text("#!/bin/sh\nexit 1\n")
            (shim / "mktemp").chmod(0o755)
            for script in SHELL_TESTS:
                with self.subTest(script=script):
                    result = run_in(work, ["bash", str(ROOT / script)],
                                    PATH=f"{shim}{os.pathsep}{os.environ['PATH']}")
                    self.assertEqual(result.returncode, 70, result.stdout + result.stderr)
                    self.assertIn("cannot create a temporary directory", result.stderr)
                    self.assertEqual([path.name for path in work.iterdir()], ["canary"])

    def test_unusable_tmpdir_stops_before_any_work(self):
        with tempfile.TemporaryDirectory() as directory:
            for script in ("tests/syntax", "tests/test-chezmoi-update-helpers.sh"):
                with self.subTest(script=script):
                    result = run_in(directory, ["bash", str(ROOT / script)],
                                    TMPDIR=str(Path(directory) / "missing"))
                    self.assertEqual(result.returncode, 70, result.stdout + result.stderr)
                    self.assertIn("TMPDIR is not a usable directory", result.stderr)
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_removal_accepts_only_helper_directories(self):
        # Every refused path is inside this test's own directory, so a broken
        # guard can only remove test data.
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory).resolve()
            outside = base / "outside"
            outside.mkdir()
            script = f'''
. "{HELPER}"
new_test_temp_dir made
mkdir "$made/nested"
for path in "$PWD" "{base}" "{outside}" "{base}/chezmoi-test." "$made/nested" "$made/.." \\
        "$made/../outside" "{outside}/chezmoi-test.x"; do
    if remove_test_temp_dir "$path" 2>/dev/null; then echo "REMOVED $path"; fi
done
remove_test_temp_dir "" && echo EMPTY-IGNORED
[ -d "$made/nested" ] && echo KEPT
remove_test_temp_dir "$made" && [ ! -e "$made" ] && echo REMOVED-OWN
'''
            result = run_in(outside, ["bash", "-c", script], TMPDIR=str(base))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn("REMOVED ", result.stdout)
            for marker in ("EMPTY-IGNORED", "KEPT", "REMOVED-OWN"):
                self.assertIn(marker, result.stdout)
            self.assertTrue(outside.is_dir())

    def test_shell_tests_use_the_helper(self):
        unsafe = re.compile(r"\bmktemp\b|\brm\s+-\w*[rR]\w*f|\brm\s+-\w*f\w*[rR]")
        files = list(SHELL_TESTS) + [str(path.relative_to(ROOT)) for path in (ROOT / "tests/lib").glob("*.sh")]
        for relative in files:
            if relative == "tests/lib/temp.sh":
                continue
            for number, line in enumerate((ROOT / relative).read_text().splitlines(), 1):
                if unsafe.search(line) and not line.lstrip().startswith("#"):
                    self.fail(f"{relative}:{number} creates or removes directories without tests/lib/temp.sh")


if __name__ == "__main__":
    unittest.main()
