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

    def test_zshrc_init_cache_survives_a_failed_generator(self):
        rendered = subprocess.run(["chezmoi", "--source", str(ROOT), "execute-template"],
                                  input=(ROOT / "dot_zshrc.tmpl").read_text(),
                                  text=True, capture_output=True, check=True).stdout
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory) / "home"
            bin_dir = Path(directory) / "bin"
            home.mkdir()
            bin_dir.mkdir()
            zshrc = Path(directory) / "zshrc"
            zshrc.write_text(rendered)
            starship = bin_dir / "starship"
            starship.write_text('#!/bin/sh\necho "STARSHIP_MARK=$STARSHIP_OUT"\n'
                                '[ "$STARSHIP_OUT" != fail ]\n')
            starship.chmod(0o755)
            cache = home / ".cache/starship-init.zsh"
            env = {**os.environ, "HOME": str(home), "ZDOTDIR": str(home), "ZSH_TEST_MODE": "1",
                   "NOTMUX": "1", "PATH": f"{bin_dir}:/usr/bin:/bin"}
            for name in ("ZSH_PROFILE_STARTUP", "DOTFILES_MISE_BIN"):
                env.pop(name, None)

            def start(output):
                result = subprocess.run(
                    ["zsh", "-fc", f'source "{zshrc}"; print -r -- "mark=${{STARSHIP_MARK:-}}"'],
                    env={**env, "STARSHIP_OUT": output}, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                # The home has no ~/.config/shell; startup must still complete.
                self.assertEqual(result.stderr, "")
                return result.stdout.splitlines()[-1]

            # A failed first run leaves no cache and no temporary file.
            self.assertEqual(start("fail"), "mark=")
            self.assertEqual(list(cache.parent.iterdir()), [])
            # An empty cache from an older zshrc is replaced.
            cache.write_text("")
            self.assertEqual(start("one"), "mark=one")
            # A current cache is used without a new generator run.
            self.assertEqual(start("two"), "mark=one")
            # A failed refresh for a newer binary keeps the last good cache.
            newer = cache.stat().st_mtime + 10
            os.utime(starship, (newer, newer))
            self.assertEqual(start("fail"), "mark=one")
            self.assertEqual([path.name for path in cache.parent.iterdir()], [cache.name])
            self.assertEqual(start("three"), "mark=three")


if __name__ == "__main__":
    unittest.main()
