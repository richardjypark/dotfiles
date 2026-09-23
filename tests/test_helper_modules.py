#!/usr/bin/env python3
"""Offline checks for shared setup helper boundaries."""

import os
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "dot_local/private_lib/chezmoi-helpers.sh"


class HelperModulesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / "home"
        self.home.mkdir()
        self.state = self.home / "state"
        self.env = dict(os.environ, HOME=str(self.home), STATE_DIR=str(self.state),
                        PATH="/usr/bin:/bin", VERBOSE="false")
        self.env.pop("CHEZMOI_HELPERS_LOADED", None)

    def bash(self, code):
        return subprocess.run(["/bin/bash", "-c", f'set -euo pipefail\n. "{HELPER}"\n{code}'],
                              env=self.env, capture_output=True, text=True, timeout=10)

    def test_loading_does_not_create_state(self):
        result = self.bash("command -v install_checked_binary >/dev/null")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.state.exists())

    def test_missing_module_fails_load(self):
        facade = self.home / "chezmoi-helpers.sh"
        shutil.copyfile(HELPER, facade)
        result = subprocess.run(["/bin/bash", "-c", f'. "{facade}"'], env=self.env,
                                capture_output=True, text=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("core.sh", result.stderr)

    def test_quiet_failure_keeps_status_and_diagnostic(self):
        result = self.bash('run_quiet bash -c "echo fixture-failure >&2; exit 23"')
        self.assertEqual(result.returncode, 23)
        self.assertIn("fixture-failure", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_failed_candidate_preserves_old_binary(self):
        old = self.home / "old"
        new = self.home / "new"
        dest = self.home / "bin/tool"
        dest.parent.mkdir()
        old.write_text("#!/bin/sh\necho old\n")
        new.write_text("#!/bin/sh\nexit 7\n")
        shutil.copyfile(old, dest)
        for path in (new, dest):
            path.chmod(0o755)
        result = self.bash(f'install_checked_binary "{new}" "{dest}"')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(dest.read_bytes(), old.read_bytes())

    def test_shared_homebrew_flow_keeps_fallback_policy(self):
        fake_bin = self.home / "fake-bin"
        fake_bin.mkdir()
        log = self.home / "brew.log"
        brew = fake_bin / "brew"
        brew.write_text('''#!/bin/sh
echo "$*" >> "$BREW_LOG"
case "$1" in
    list) exit 1 ;;
    install)
        case " $* " in *" --quiet "*) exit 7 ;; esac
        exit "$BREW_RESULT"
        ;;
    *) exit 2 ;;
esac
''')
        brew.chmod(0o755)
        self.env.update(PATH=f"{fake_bin}:/usr/bin:/bin", BREW_LOG=str(log),
                        BREW_RESULT="0", VERBOSE="false")
        starship = self.bash("brew_install_formula starship Starship true")
        self.assertEqual(starship.returncode, 0, starship.stderr)
        self.assertEqual(log.read_text().splitlines(), [
            "list --formula starship", "install starship --quiet", "install starship",
        ])

        log.unlink()
        self.env["BREW_RESULT"] = "9"
        jj = self.bash("brew_install_formula jj Jujutsu false")
        self.assertEqual(jj.returncode, 9)
        self.assertEqual(log.read_text().splitlines(), ["list --formula jj", "install jj"])

    def test_good_candidate_replaces_binary(self):
        new = self.home / "new"
        dest = self.home / "bin/tool"
        new.write_text("#!/bin/sh\necho good\n")
        new.chmod(0o755)
        result = self.bash(f'install_checked_binary "{new}" "{dest}"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(subprocess.check_output([str(dest)], text=True), "good\n")

    def test_onchange_template_tracks_helper_bytes(self):
        script = ROOT / ".chezmoiscripts/run_onchange_after_26-setup-jj.sh.tmpl"
        rendered = subprocess.run(
            ["chezmoi", "--source", str(ROOT), "execute-template"],
            input=script.read_text(), capture_output=True, text=True, timeout=15, check=True,
        ).stdout
        for name in ("chezmoi-helpers.sh", "chezmoi/core.sh", "chezmoi/artifacts.sh",
                     "chezmoi/npm.sh"):
            digest = hashlib.sha256((ROOT / "dot_local/private_lib" / name).read_bytes()).hexdigest()
            self.assertIn(digest, rendered)

    def test_test_support_is_not_a_managed_target(self):
        result = subprocess.run(
            ["chezmoi", "--source", str(ROOT), "managed", "--path-style", "source-relative"],
            capture_output=True, text=True, timeout=15, check=True,
        )
        managed = result.stdout.splitlines()
        self.assertFalse(any(path.startswith("tests/") for path in managed))
        self.assertFalse(any(path.startswith(".chezmoitemplates/") for path in managed))


if __name__ == "__main__":
    unittest.main()
