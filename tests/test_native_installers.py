#!/usr/bin/env python3
"""Run a complete release installer with fake network and an isolated home."""

import hashlib
import io
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
STARSHIP = ROOT / ".chezmoiscripts/run_onchange_after_12-setup-starship.sh.tmpl"


class NativeInstallerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / "home"
        self.lib = self.home / ".local/lib"
        self.bin = self.home / ".local/bin"
        self.bin.mkdir(parents=True)
        self.lib.mkdir(parents=True)
        shutil.copyfile(ROOT / "dot_local/private_lib/chezmoi-helpers.sh",
                        self.lib / "chezmoi-helpers.sh")
        shutil.copytree(ROOT / "dot_local/private_lib/chezmoi", self.lib / "chezmoi")
        self.fake_bin = self.base / "fake-bin"
        self.fake_bin.mkdir()
        self.archive = self.base / "starship.tar.gz"
        self.env = dict(os.environ, HOME=str(self.home),
                        PATH=f"{self.fake_bin}:/usr/bin:/bin",
                        GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null",
                        CHEZMOI_DOWNLOAD_CACHE_DIR=str(self.base / "cache"),
                        TRUST_ON_FIRST_USE_INSTALLERS="1", CHEZMOI_FORCE_UPDATE="1",
                        FIXTURE_ARCHIVE=str(self.archive),
                        CURL_CALLS=str(self.base / "curl-calls"), VERBOSE="false")
        self.env.pop("CHEZMOI_HELPERS_LOADED", None)
        curl = self.fake_bin / "curl"
        curl.write_text('''#!/bin/sh
out=""
while [ "$#" -gt 0 ]; do
    if [ "$1" = -o ]; then out="$2"; shift 2; else shift; fi
done
printf 'call\\n' >> "$CURL_CALLS"
cp "$FIXTURE_ARCHIVE" "$out"
''')
        curl.chmod(0o755)
        brew = self.fake_bin / "brew"
        brew.write_text("#!/bin/sh\nexit 1\n")
        brew.chmod(0o755)

    def script(self, candidate):
        data = candidate.encode()
        info = tarfile.TarInfo("starship")
        info.mode = 0o755
        info.size = len(data)
        with tarfile.open(self.archive, "w:gz") as archive:
            archive.addfile(info, io.BytesIO(data))
        sha = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        rendered = subprocess.run(
            ["chezmoi", "--source", str(ROOT), "execute-template"],
            input=STARSHIP.read_text(), capture_output=True, text=True, check=True, timeout=15,
        ).stdout
        return re.sub(r'(PINNED_STARSHIP_(?:LINUX|MACOS)_(?:X86_64|ARM64)_SHA=")[^"]+(")',
                      rf'\g<1>{sha}\2', rendered)

    def run_script(self, script):
        return subprocess.run(["/bin/bash", "-c", script], env=self.env,
                              capture_output=True, text=True, timeout=20)

    def test_install_and_repeat_do_not_download_again(self):
        script = self.script('#!/bin/sh\necho "starship 999.0.0"\n')
        result = self.run_script(script)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        installed = self.bin / "starship"
        before = installed.stat().st_mtime_ns
        self.assertTrue(installed.is_file())
        self.assertTrue(list((self.home / ".cache/chezmoi-state").glob("starship-*.done")))
        self.env["CHEZMOI_FORCE_UPDATE"] = "0"
        result = self.run_script(script)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(installed.stat().st_mtime_ns, before)
        self.assertEqual((self.base / "curl-calls").read_text().count("call"), 1)

    def test_bad_candidate_keeps_previous_command(self):
        old = self.bin / "starship"
        old.write_text('#!/bin/sh\necho "starship 999.0.0"\n')
        old.chmod(0o755)
        before = old.read_bytes()
        script = self.script('#!/bin/sh\nexit 7\n')
        result = self.run_script(script)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(old.read_bytes(), before)
        self.assertFalse(list((self.home / ".cache/chezmoi-state").glob("starship-*.done")))

    def test_missing_trust_does_not_fetch(self):
        script = self.script('#!/bin/sh\necho "starship 999.0.0"\n')
        self.env["TRUST_ON_FIRST_USE_INSTALLERS"] = "0"
        result = self.run_script(script)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.base / "curl-calls").exists())


UV = ROOT / ".chezmoiscripts/run_onchange_after_25-setup-uv.sh.tmpl"


class UvHomebrewTest(unittest.TestCase):
    """Judge Homebrew's own uv, not an older ~/.local/bin copy that shadows it."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / "home"
        lib = self.home / ".local/lib"
        lib.mkdir(parents=True)
        shutil.copyfile(ROOT / "dot_local/private_lib/chezmoi-helpers.sh", lib / "chezmoi-helpers.sh")
        shutil.copytree(ROOT / "dot_local/private_lib/chezmoi", lib / "chezmoi")
        fake_bin = self.base / "fake-bin"
        self.brew_uv = self.base / "brew/bin/uv"
        self.managed_uv = self.home / ".local/bin/uv"
        self.archive = self.base / "uv.tar.gz"
        self.env = dict(os.environ, HOME=str(self.home), PATH=f"{fake_bin}:/usr/bin:/bin",
                        GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null",
                        CHEZMOI_DOWNLOAD_CACHE_DIR=str(self.base / "cache"),
                        TRUST_ON_FIRST_USE_INSTALLERS="1", CHEZMOI_FORCE_UPDATE="1",
                        FIXTURE_ARCHIVE=str(self.archive), FAKE_BREW_PREFIX=str(self.base / "brew"),
                        CURL_CALLS=str(self.base / "curl-calls"), VERBOSE="false")
        for name in ("CHEZMOI_HELPERS_LOADED", "CHEZMOI_MACOS_MAINTENANCE_MODE"):
            self.env.pop(name, None)
        self.tool(fake_bin / "curl", '''#!/bin/sh
out=""
while [ "$#" -gt 0 ]; do
    if [ "$1" = -o ]; then out="$2"; shift 2; else shift; fi
done
printf 'call\\n' >> "$CURL_CALLS"
cp "$FIXTURE_ARCHIVE" "$out"
''')
        self.tool(fake_bin / "uname", '#!/bin/sh\ncase "$1" in -s) echo Darwin ;; -m) echo arm64 ;; esac\n')
        # Homebrew reports uv as installed and current.
        self.tool(fake_bin / "brew", '#!/bin/sh\ncase "$1" in\n    --prefix) echo "$FAKE_BREW_PREFIX" ;;\n'
                  '    list|outdated) ;;\n    *) echo "unexpected brew $*" >&2; exit 1 ;;\nesac\n')
        self.tool(self.managed_uv, self.fake_uv("0.0.1"))
        self.script, self.pin = self.render()

    @staticmethod
    def tool(path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        path.chmod(0o755)

    @staticmethod
    def fake_uv(version):
        return (f'#!/bin/sh\ncase "$1" in\n    --version) echo "uv {version}" ;;\n'
                '    python) echo "cpython-3.12.0-macos-aarch64-none" ;;\nesac\n')

    def render(self):
        rendered = subprocess.run(
            ["chezmoi", "--source", str(ROOT), "execute-template"],
            input=UV.read_text(), capture_output=True, text=True, check=True, timeout=15,
        ).stdout
        return rendered, re.search(r'PINNED_UV_VERSION="([^"]+)"', rendered).group(1)

    def run_script(self, script):
        return subprocess.run(["/bin/bash", "-c", script], env=self.env,
                              capture_output=True, text=True, timeout=20)

    def test_current_homebrew_uv_replaces_older_shadowing_copy(self):
        self.tool(self.brew_uv, self.fake_uv(self.pin))
        result = self.run_script(self.script)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertNotIn("below pinned target", output)
        self.assertFalse((self.base / "curl-calls").exists())
        self.assertTrue(self.managed_uv.is_symlink())
        self.assertEqual(os.readlink(self.managed_uv), str(self.brew_uv))

    def test_older_homebrew_uv_reports_its_own_version(self):
        self.tool(self.brew_uv, self.fake_uv("0.0.2"))
        data = self.fake_uv(self.pin).encode()
        info = tarfile.TarInfo("uv-aarch64-apple-darwin/uv")
        info.mode = 0o755
        info.size = len(data)
        with tarfile.open(self.archive, "w:gz") as archive:
            archive.addfile(info, io.BytesIO(data))
        sha = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        script = re.sub(r'(PINNED_UV_MACOS_ARM64_SHA=")[^"]+(")', rf'\g<1>{sha}\2', self.script)
        result = self.run_script(script)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertIn(f"Homebrew uv version (0.0.2) is below pinned target {self.pin}", output)
        self.assertEqual((self.base / "curl-calls").read_text().count("call"), 1)
        self.assertFalse(self.managed_uv.is_symlink())
        self.assertIn(f"uv {self.pin}", self.managed_uv.read_text())


if __name__ == "__main__":
    unittest.main()
