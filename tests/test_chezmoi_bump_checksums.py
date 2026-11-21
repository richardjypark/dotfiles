#!/usr/bin/env python3
"""chezmoi-bump passes platform checksums as data and refuses an incomplete set."""

from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BUMP = ROOT / "dot_local/bin/executable_chezmoi-bump"
SHA = {platform: str(index) * 64 for index, platform in enumerate(
    ("linux_x86_64", "linux_arm64", "macos_x86_64", "macos_arm64"), 1)}
ASSET = {"bun-linux-x64.zip": "linux_x86_64", "bun-linux-aarch64.zip": "linux_arm64",
         "bun-darwin-x64.zip": "macos_x86_64", "bun-darwin-aarch64.zip": "macos_arm64"}


def run(body, chezmoi_dir, missing=""):
    stubs = "\n".join(f'    *{asset}) printf "%s\\n" {SHA[key]} ;;' for asset, key in ASSET.items())
    script = f'''set -euo pipefail
. "{BUMP}"
CHEZMOI_DIR="{chezmoi_dir}"
artifact_url_exists() {{ case "$1" in *"{missing or 'no-such-asset'}") return 1 ;; esac; }}
sha256_shasums() {{
    case "$2" in
{stubs}
    esac
}}
{body}
'''
    return subprocess.run(["bash", "-c", script], capture_output=True, text=True, timeout=60)


class ChecksumHandOff(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)
        keys = "".join(f'{key}_sha256 = "{"0" * 64}"\n' for key in SHA)
        (self.dir / ".chezmoidata.toml").write_text(f'[pinned.bun]\nversion = "bun-v1.0.0"\n{keys}')

    def test_each_platform_checksum_is_one_tab_separated_row(self):
        result = run('fetch_checksums bun bun-v1.2.3 shasums 4', self.dir)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [f"sha\t{key}_sha256\t{SHA[key]}" for key in SHA])

    def test_a_missing_artifact_is_an_error_row_and_no_checksum(self):
        result = run('fetch_checksums bun bun-v1.2.3 shasums 4', self.dir, missing="bun-darwin-x64.zip")
        rows = result.stdout.splitlines()
        self.assertEqual(len([row for row in rows if row.startswith("sha\t")]), 3)
        self.assertIn("error\tbun: missing artifact bun-darwin-x64.zip", "\n".join(rows))

    def test_manifest_uses_the_rows_it_is_given(self):
        body = '''checksums="$(fetch_checksums bun bun-v1.2.3 shasums 4)"
build_dep_manifest bun bun-v1.0.0 bun-v1.2.3 "$checksums"
print_manifest_changes'''
        result = run(body, self.dir)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for key, sha in SHA.items():
            self.assertIn(f"{key}_sha256: {'0' * 64} → {sha}", result.stdout)
        self.assertIn("version: bun-v1.0.0 → bun-v1.2.3", result.stdout)

    def test_bump_refuses_an_incomplete_checksum_set(self):
        body = '''get_current_version() { echo bun-v1.0.0; }
get_latest_version() { echo bun-v1.2.3; }
status=0
bump_dep bun || status=$?
echo "status=$status"'''
        result = run(body, self.dir, missing="bun-linux-x64.zip")
        self.assertIn("status=1", result.stdout, result.stderr)
        self.assertIn("Installability gate failed", result.stdout)
        self.assertIn("    - bun: missing artifact bun-linux-x64.zip", result.stdout)
        self.assertEqual((self.dir / ".chezmoidata.toml").read_text().count("0" * 64), 4)


if __name__ == "__main__":
    unittest.main()
