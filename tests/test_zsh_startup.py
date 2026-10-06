#!/usr/bin/env python3
"""Exercise managed zshenv with errexit, nounset, and a temporary mise path."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
OMARCHY_BOOTSTRAP = Path("/usr/share/omarchy/default/bash/env-bootstrap")


class ZshStartupTest(unittest.TestCase):
    def run_zshenv_omarchy_path(self, home, omarchy_path=None):
        env = {**os.environ, "HOME": str(home), "ZDOTDIR": str(home)}
        env.pop("ZSH_PROFILE_STARTUP", None)
        env.pop("OMARCHY_PATH", None)
        if omarchy_path is not None:
            env["OMARCHY_PATH"] = omarchy_path
        result = subprocess.run(
            ["zsh", "-euc", f'source "{ROOT / "dot_zshenv"}"; print -r -- "${{OMARCHY_PATH:-}}"'],
            env=env, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        return result.stdout.strip()

    def test_zshenv_sets_missing_omarchy_path_only_on_omarchy_hosts(self):
        with tempfile.TemporaryDirectory() as directory:
            omarchy_path = self.run_zshenv_omarchy_path(Path(directory))
        if OMARCHY_BOOTSTRAP.is_file():
            self.assertTrue(omarchy_path.startswith("/"), omarchy_path)
        else:
            self.assertEqual(omarchy_path, "")

    def test_zshenv_keeps_existing_omarchy_path(self):
        with tempfile.TemporaryDirectory() as directory:
            omarchy_path = self.run_zshenv_omarchy_path(Path(directory), "/opt/omarchy-test")
        self.assertEqual(omarchy_path, "/opt/omarchy-test")

    def test_zshenv_succeeds_without_optional_profile_variable(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory) / "home"
            bin_dir = Path(directory) / "bin"
            shims = Path(directory) / "mise/shims"
            home.mkdir()
            bin_dir.mkdir()
            shims.mkdir(parents=True)
            mise = bin_dir / "mise"
            mise.write_text("#!/bin/sh\nexit 0\n")
            mise.chmod(0o755)
            env = {**os.environ, "HOME": str(home), "ZDOTDIR": directory,
                   "MISE_DATA_DIR": str(shims.parent), "PATH": f"{bin_dir}:{os.environ['PATH']}"}
            env.pop("ZSH_PROFILE_STARTUP", None)
            for flags in ("c", "ec", "uc", "euc"):
                for profile in (False, True):
                    with self.subTest(flags=flags, profile=profile):
                        current = {**env}
                        if profile:
                            current["ZSH_PROFILE_STARTUP"] = "1"
                        result = subprocess.run(
                            ["zsh", f"-{flags}", f'source "{ROOT / "dot_zshenv"}"; print -r -- "$PATH"'],
                            env=current, capture_output=True, text=True,
                        )
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertEqual(result.stderr, "")
                        entries = result.stdout.strip().split(":")
                        self.assertEqual(entries[0], str(home / ".bun/bin"))
                        self.assertIn(str(shims), entries)
                        self.assertEqual(entries.count(str(shims)), 1)


if __name__ == "__main__":
    unittest.main()
