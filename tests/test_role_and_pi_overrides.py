#!/usr/bin/env python3
"""Check role rendering and local Pi override convergence in temporary homes."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[1]
LOCAL_DATA = ROOT / "scripts/set-chezmoi-local-data.py"
OVERRIDE = ROOT / ".chezmoiscripts/run_after_98-pi-local-overrides.sh.tmpl"


class RoleAndOverrideTest(unittest.TestCase):
    def test_omarchy_uses_managed_zshrc_with_herdr(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            home = root / "home"
            home.mkdir()
            for name in (".chezmoiignore", "dot_zshenv", "dot_zshrc.tmpl", "private_dot_config/ghostty/config",
                         ".chezmoitemplates/resolved-role", ".chezmoitemplates/resolved-profile"):
                target = source / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / name).read_bytes())
            config = root / "config.toml"
            config.write_text('[data]\nrole = "workstation"\nprofile = "omarchy"\n')
            command = ["chezmoi", "--source", str(source), "--destination", str(home),
                       "--config", str(config)]
            env = {**os.environ, "HOME": str(home)}
            managed = subprocess.run(command + ["managed"], env=env, check=True,
                                     capture_output=True, text=True).stdout.splitlines()
            ignored = subprocess.run(command + ["ignored"], env=env, check=True,
                                     capture_output=True, text=True).stdout.splitlines()
            self.assertIn(".zshrc", managed)
            # .zshrc activates mise only when .zshenv sets DOTFILES_MISE_BIN.
            self.assertIn(".zshenv", managed)
            self.assertIn(".config/ghostty/config", ignored)
            rendered = subprocess.run(command + ["cat", str(home / ".zshrc")], env=env,
                                      check=True, capture_output=True, text=True).stdout
            self.assertIn("exec herdr", rendered)
            self.assertIn('[[ -z "${HERDR_ENV:-}" ]]', rendered)
            self.assertNotIn("exec tmux new-session", rendered)
            self.assertIn('"$DOTFILES_MISE_BIN" activate zsh', rendered)
            zshenv = subprocess.run(command + ["cat", str(home / ".zshenv")], env=env,
                                    check=True, capture_output=True, text=True).stdout
            self.assertIn("DOTFILES_MISE_BIN=", zshenv)

    def test_pi_source_returns_after_local_override_is_removed(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory) / "home"
            source = Path(directory) / "source"
            home.mkdir()
            (source / "dot_pi/agent").mkdir(parents=True)
            (source / ".chezmoiignore").write_bytes((ROOT / ".chezmoiignore").read_bytes())
            (source / ".chezmoitemplates").mkdir()
            for name in ("resolved-role", "resolved-profile"):
                (source / ".chezmoitemplates" / name).write_bytes(
                    (ROOT / ".chezmoitemplates" / name).read_bytes())
            for name in ("settings.json", "keybindings.json"):
                (source / "dot_pi/agent" / name).write_bytes((ROOT / "dot_pi/agent" / name).read_bytes())
            config = Path(directory) / "config.toml"
            config.write_text('[git]\nautoCommit = false\n[data]\nrole = "workstation"\nprofile = "standard"\n')
            env = {**os.environ, "HOME": str(home)}
            base = ["chezmoi", "--source", str(source), "--destination", str(home),
                    "--config", str(config), "--persistent-state", str(Path(directory) / "state")]
            local_dir = home / ".config/dotfiles/pi"
            local_dir.mkdir(parents=True)
            ignored = subprocess.run(base + ["ignored"], env=env, check=True,
                                     capture_output=True, text=True).stdout
            # The 98 script merges managed Pi settings, so chezmoi never owns the file.
            self.assertIn(".pi/agent/settings.json", ignored)
            override = local_dir / "keybindings.local.json"
            target = home / ".pi/agent/keybindings.json"
            override.write_text('{"local": true}\n')
            ignored = subprocess.run(base + ["ignored"], env=env, check=True,
                                     capture_output=True, text=True).stdout
            self.assertIn(".pi/agent/keybindings.json", ignored)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(override.read_bytes())
            override.unlink()
            applied = subprocess.run(base + ["apply", "--exclude=scripts", "--force"], env=env,
                                     capture_output=True, text=True)
            self.assertEqual(applied.returncode, 0, applied.stdout + applied.stderr)
            self.assertEqual(target.read_bytes(), (ROOT / "dot_pi/agent/keybindings.json").read_bytes())

    def test_role_change_reruns_onchange_with_one_persistent_state(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            destination = root / "home"
            templates = source / ".chezmoitemplates"
            scripts = source / ".chezmoiscripts"
            templates.mkdir(parents=True)
            scripts.mkdir()
            destination.mkdir()
            (templates / "resolved-role").write_bytes((ROOT / ".chezmoitemplates/resolved-role").read_bytes())
            (scripts / "run_onchange_after_00-role.sh.tmpl").write_text(
                '#!/bin/sh\nprintf "%s\\n" "{{ includeTemplate "resolved-role" . }}" '
                '>> "{{ .chezmoi.destDir }}/role-log"\n'
            )
            config = root / "chezmoi.toml"
            command = ["chezmoi", "--source", str(source), "--destination", str(destination),
                       "--config", str(config), "--persistent-state", str(root / "state"), "apply"]
            for role in ("server", "workstation", "server"):
                config.write_text(f'[git]\nautoCommit = false\n[data]\nrole = "{role}"\n')
                subprocess.run(command, check=True, capture_output=True, text=True)
            self.assertEqual((destination / "role-log").read_text().splitlines(),
                             ["server", "workstation", "server"])

    def test_always_run_script_does_not_count_as_file_drift(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            destination = root / "home"
            scripts = source / ".chezmoiscripts"
            scripts.mkdir(parents=True)
            destination.mkdir()
            (source / "dot_probe").write_text("same\n")
            (scripts / "run_after_00-always.sh").write_text("#!/bin/sh\ntrue\n")
            config = root / "chezmoi.toml"
            config.write_text("[git]\nautoCommit = false\n")
            base = ["chezmoi", "--source", str(source), "--destination", str(destination),
                    "--config", str(config), "--persistent-state", str(root / "state")]
            subprocess.run(base + ["apply"], check=True, capture_output=True, text=True)
            all_status = subprocess.run(base + ["status"], check=True, capture_output=True, text=True).stdout
            file_status = subprocess.run(base + ["status", "--exclude=scripts"],
                                         check=True, capture_output=True, text=True).stdout
            self.assertTrue(all_status.strip())
            self.assertEqual(file_status.strip(), "")

    def test_saved_role_and_explicit_override(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "chezmoi.toml"
            config.write_text('[data]\nrole = "server"\nprofile = "standard"\n')
            command = ["chezmoi", "--source", str(ROOT), "--config", str(config)]
            script = (ROOT / ".chezmoiscripts/run_onchange_after_36-setup-codex.sh.tmpl").read_text()
            env = {**os.environ, "CHEZMOI_ROLE": "", "CHEZMOI_PROFILE": ""}
            server = subprocess.run(command + ["execute-template"], input=script, text=True,
                                    capture_output=True, check=True, env=env).stdout
            self.assertIn('if [ "server" = "server" ]; then', server)
            env["CHEZMOI_ROLE"] = "workstation"
            workstation = subprocess.run(command + ["execute-template"], input=script, text=True,
                                         capture_output=True, check=True, env=env).stdout
            self.assertIn('if [ "workstation" = "server" ]; then', workstation)
            self.assertNotEqual(server, workstation)
            env["CHEZMOI_ROLE"] = "invalid"
            result = subprocess.run(command + ["execute-template"], input=script, text=True,
                                    capture_output=True, env=env)
            self.assertNotEqual(result.returncode, 0)

    def test_local_data_preserves_other_config(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            config = home / "active.toml"
            config.write_text('[git]\nautoPush = false\n\n[data]\nother = "keep"\nrole = "workstation"\n')
            bin_dir = home / "bin"
            bin_dir.mkdir()
            stub = bin_dir / "chezmoi"
            stub.write_text('#!/bin/sh\nprintf \'{"chezmoi":{"configFile":"%s"}}\\n\' "$TEST_CONFIG_PATH"\n')
            stub.chmod(0o755)
            env = {**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}", "TEST_CONFIG_PATH": str(config)}
            command = ["python3", str(LOCAL_DATA), "--role", "server", "--profile", "omarchy"]
            subprocess.run(command, env=env, check=True)
            first = config.read_bytes()
            mtime = config.stat().st_mtime_ns
            self.assertIn(b'other = "keep"', first)
            self.assertIn(b'role = "server"', first)
            self.assertIn(b'profile = "omarchy"', first)
            subprocess.run(command, env=env, check=True)
            self.assertEqual(config.read_bytes(), first)
            self.assertEqual(config.stat().st_mtime_ns, mtime)

            for suffix, content in ((".json", '{"git":{"autoPush":false},"data":{"other":"keep"}}'),
                                    (".yaml", 'git:\n  autoPush: false\ndata:\n  other: keep\n')):
                structured = home / f"active{suffix}"
                structured.write_text(content)
                env["TEST_CONFIG_PATH"] = str(structured)
                subprocess.run(command, env=env, check=True)
                parsed = json.loads(structured.read_text()) if suffix == ".json" else yaml.safe_load(structured.read_text())
                self.assertEqual(parsed["data"], {"other": "keep", "role": "server", "profile": "omarchy"})
                self.assertFalse(parsed["git"]["autoPush"])

    def test_pi_override_valid_invalid_and_unchanged(self):
        rendered = subprocess.run(["chezmoi", "--source", str(ROOT), "execute-template"],
                                  input=OVERRIDE.read_text(), text=True, capture_output=True, check=True).stdout
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            helper = home / ".local/lib/chezmoi-helpers.sh"
            helper.parent.mkdir(parents=True)
            helper.write_text('eecho() { :; }\n')
            local_dir = home / ".config/dotfiles/pi"
            local_dir.mkdir(parents=True)
            source = local_dir / "settings.local.json"
            target = home / ".pi/agent/settings.json"
            package = json.loads((ROOT / "dot_pi/agent/settings.json").read_text())["packages"][0]
            source.write_text(json.dumps({"packages": [package], "defaultModel": "local"}))
            env = {**os.environ, "HOME": str(home)}
            subprocess.run(["bash", "-"], input=rendered, text=True, env=env, check=True)
            first = target.read_bytes()
            mtime = target.stat().st_mtime_ns
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
            subprocess.run(["bash", "-"], input=rendered, text=True, env=env, check=True)
            self.assertEqual(target.stat().st_mtime_ns, mtime)
            source.write_text("{")
            result = subprocess.run(["bash", "-"], input=rendered, text=True, env=env, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(target.read_bytes(), first)
            source.write_text(json.dumps({"packages": ["different"]}))
            result = subprocess.run(["bash", "-"], input=rendered, text=True, env=env, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(target.read_bytes(), first)

    def test_pi_settings_merge_keeps_tool_keys(self):
        rendered = subprocess.run(["chezmoi", "--source", str(ROOT), "execute-template"],
                                  input=OVERRIDE.read_text(), text=True, capture_output=True, check=True).stdout
        managed = json.loads((ROOT / "dot_pi/agent/settings.json").read_text())
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            helper = home / ".local/lib/chezmoi-helpers.sh"
            helper.parent.mkdir(parents=True)
            helper.write_text('eecho() { :; }\nvecho() { :; }\n')
            target = home / ".pi/agent/settings.json"
            env = {**os.environ, "HOME": str(home)}

            def run():
                return subprocess.run(["bash", "-"], input=rendered, text=True, env=env,
                                      capture_output=True)

            # A missing file gets the managed settings.
            self.assertEqual(run().returncode, 0)
            self.assertEqual(json.loads(target.read_text()), managed)
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)

            # Pi-written keys stay, managed drift is reset, and a match is not rewritten.
            drifted = {**managed, "theme": "dark", "defaultModel": "local",
                       "compaction": {**managed["compaction"], "enabled": False, "extra": 1}}
            target.write_text(json.dumps(drifted))
            self.assertEqual(run().returncode, 0)
            merged = json.loads(target.read_text())
            self.assertEqual(merged["theme"], "dark")
            self.assertEqual(merged["compaction"]["extra"], 1)
            self.assertEqual({key: merged[key] for key in managed},
                             {**managed, "compaction": {**managed["compaction"], "extra": 1}})
            mtime = target.stat().st_mtime_ns
            self.assertEqual(run().returncode, 0)
            self.assertEqual(target.stat().st_mtime_ns, mtime)

            # Invalid JSON fails without a write.
            target.write_text("{")
            self.assertNotEqual(run().returncode, 0)
            self.assertEqual(target.read_text(), "{")

            # An empty file is treated as missing.
            target.write_text("")
            self.assertEqual(run().returncode, 0)
            self.assertEqual(json.loads(target.read_text()), managed)

    def test_pi_settings_merge_without_jq(self):
        rendered = subprocess.run(["chezmoi", "--source", str(ROOT), "execute-template"],
                                  input=OVERRIDE.read_text(), text=True, capture_output=True, check=True).stdout
        managed = json.loads((ROOT / "dot_pi/agent/settings.json").read_text())
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory) / "home"
            helper = home / ".local/lib/chezmoi-helpers.sh"
            helper.parent.mkdir(parents=True)
            helper.write_text('eecho() { printf "%s\\n" "$*"; }\nvecho() { :; }\n')
            # A PATH with the tools the script needs, but no jq.
            tools = Path(directory) / "bin"
            tools.mkdir()
            for name in ("bash", "cat", "chmod", "cmp", "dirname", "install", "mkdir",
                         "mktemp", "mv", "rm", "stat", "uname"):
                (tools / name).symlink_to(shutil.which(name))
            env = {"HOME": str(home), "PATH": str(tools)}
            target = home / ".pi/agent/settings.json"

            def run():
                return subprocess.run([str(tools / "bash"), "-"], input=rendered, text=True,
                                      env=env, capture_output=True)

            # A new host without jq still gets the managed settings.
            result = run()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(target.read_text()), managed)

            # An existing file without jq is kept, and apply does not fail.
            target.write_text(json.dumps({**managed, "theme": "dark", "defaultModel": "local"}))
            before = target.read_bytes()
            result = run()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("jq is not installed", result.stdout)
            self.assertEqual(target.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
