#!/usr/bin/env python3
"""Check that modify templates merge managed keys and keep tool-written keys."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
CLAUDE = "private_dot_claude/modify_private_settings.json"
# (source, target, managed key path, drift value, tool text, tool key path, tool value)
CASES = (
    ("private_dot_codex/modify_private_config.toml", ".codex/config.toml",
     ("model",), "gpt-older",
     '\n[hooks.state."/tmp/hooks.json:session_start:0:0"]\ntrusted_hash = "sha256:abc"\n',
     ("hooks", "state", "/tmp/hooks.json:session_start:0:0", "trusted_hash"), "sha256:abc"),
    ("private_dot_config/mise/modify_config.toml", ".config/mise/config.toml",
     ("tools", "node"), "1.0.0",
     '\n[tools.extra]\nversion = "latest"\n',
     ("tools", "extra", "version"), "latest"),
)


def lookup(config, path):
    for part in path:
        config = config[part]
    return config


class ManagedConfigMergeTest(unittest.TestCase):
    def test_modify_templates_keep_tool_keys_and_reset_managed_drift(self):
        for (source_name, target_name, managed_path, drift_value,
             tool_text, tool_path, tool_value) in CASES:
            with self.subTest(target=target_name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                source = root / "source" / source_name
                source.parent.mkdir(parents=True)
                source.write_bytes((ROOT / source_name).read_bytes())
                home = root / "home"
                home.mkdir()
                config = root / "config.toml"
                config.write_text("[data]\n")
                command = ["chezmoi", "--source", str(root / "source"), "--destination", str(home),
                           "--config", str(config), "--persistent-state", str(root / "state")]
                env = {**os.environ, "HOME": str(home)}
                target = home / target_name

                def chezmoi(*args):
                    return subprocess.run(command + list(args), env=env, check=True,
                                          capture_output=True, text=True).stdout

                # A new file gets the managed text with its comments.
                chezmoi("apply", "--no-tty")
                created = target.read_text()
                self.assertTrue(created.startswith("#"))
                expected = lookup(tomllib.loads(created), managed_path)

                # Tool-written keys are not drift: no status line and no rewrite.
                target.write_text(created + tool_text)
                with_tool_keys = target.read_bytes()
                self.assertEqual(chezmoi("status"), "")
                chezmoi("apply", "--no-tty")
                self.assertEqual(target.read_bytes(), with_tool_keys)

                # Managed drift is reset and tool-written keys stay.
                target.write_text(created.replace(f'"{expected}"', f'"{drift_value}"', 1) + tool_text)
                self.assertIn(target_name, chezmoi("status"))
                chezmoi("apply", "--no-tty")
                merged = tomllib.loads(target.read_text())
                self.assertEqual(lookup(merged, managed_path), expected)
                self.assertEqual(lookup(merged, tool_path), tool_value)
                self.assertEqual(chezmoi("status"), "")

    def apply_to(self, source_name, target_name, live_text, template_text=None, parse=tomllib.loads):
        """Apply one modify template to a live file; return the parsed result and `chezmoi status`."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source" / source_name
            source.parent.mkdir(parents=True)
            source.write_text(template_text or (ROOT / source_name).read_text())
            home = root / "home"
            target = home / target_name
            target.parent.mkdir(parents=True)
            target.write_text(live_text)
            config = root / "config.toml"
            config.write_text("[data]\n")
            command = ["chezmoi", "--source", str(root / "source"), "--destination", str(home),
                       "--config", str(config), "--persistent-state", str(root / "state")]
            env = {**os.environ, "HOME": str(home)}
            subprocess.run(command + ["apply", "--no-tty"], env=env, check=True,
                           capture_output=True, text=True)
            result = target.read_text()
            status = subprocess.run(command + ["status"], env=env, check=True,
                                    capture_output=True, text=True).stdout
            return parse(result), status

    def test_codex_removes_unsafe_values_at_any_depth(self):
        live = """approval_policy = "never"
sandbox_mode = "danger-full-access"
bypass_hook_trust = true
dangerously_bypass_approvals_and_sandbox = true
[profiles.fast]
approval_policy = "never"
sandbox_mode = "danger-full-access"
model = "keep-me"
[profiles.fast.sandbox_workspace_write]
dangerously_allow_all_unix_sockets = true
network_access = true
[sandbox_workspace_write]
dangerously_allow_non_loopback_proxy = true
dangerously_allow_all_unix_sockets = false
[hooks.state."/tmp/hooks.json:session_start:0:0"]
trusted_hash = "sha256:abc"
"""
        config, status = self.apply_to("private_dot_codex/modify_private_config.toml",
                                       ".codex/config.toml", live)
        for key in ("approval_policy", "sandbox_mode", "bypass_hook_trust",
                    "dangerously_bypass_approvals_and_sandbox"):
            self.assertNotIn(key, config)
        self.assertEqual(config["profiles"]["fast"], {"model": "keep-me",
                                                       "sandbox_workspace_write": {"network_access": True}})
        self.assertEqual(config["sandbox_workspace_write"], {"dangerously_allow_all_unix_sockets": False})
        self.assertEqual(config["hooks"]["state"]["/tmp/hooks.json:session_start:0:0"]["trusted_hash"],
                         "sha256:abc")
        self.assertEqual(config["model"], "gpt-6-sol")
        self.assertEqual(status, "")

    def test_codex_keeps_safe_explicit_values(self):
        live = 'approval_policy = "on-request"\nsandbox_mode = "workspace-write"\n'
        config, status = self.apply_to("private_dot_codex/modify_private_config.toml",
                                       ".codex/config.toml", live)
        self.assertEqual(config["approval_policy"], "on-request")
        self.assertEqual(config["sandbox_mode"], "workspace-write")
        self.assertEqual(status, "")

    def test_mise_removes_auto_trust_settings(self):
        live = """[settings]
trusted_config_paths = ["/"]
yes = true
experimental = true
[tools]
node = "24.14.0"
claude = "latest"
"""
        config, status = self.apply_to("private_dot_config/mise/modify_config.toml",
                                       ".config/mise/config.toml", live)
        self.assertEqual(config["settings"], {"experimental": True})
        self.assertEqual(config["tools"]["claude"], "latest")
        self.assertEqual(status, "")

    def test_retired_keys_are_deleted(self):
        for source_name, target_name, live, path in (
            ("private_dot_codex/modify_private_config.toml", ".codex/config.toml",
             '[features]\nold_flag = true\nother = 1\n', ("features", "old_flag")),
            ("private_dot_config/mise/modify_config.toml", ".config/mise/config.toml",
             '[tools]\nold_tool = "1"\n', ("tools", "old_tool")),
        ):
            with self.subTest(target=target_name):
                template = (ROOT / source_name).read_text()
                marker = "{{- $retired := list -}}"
                self.assertEqual(template.count(marker), 1)
                template = template.replace(marker, '{{- $retired := list "%s" -}}' % ".".join(path))
                config, status = self.apply_to(source_name, target_name, live, template)
                self.assertNotIn(path[1], config[path[0]])
                self.assertEqual(status, "")

    def test_claude_resets_unsafe_settings_and_keeps_the_rest(self):
        live = json.dumps({
            "model": "opus",
            "hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": "x >/dev/null 2>&1"}]}]},
            "env": {"EXAMPLE": "keep"},
            "skipDangerousModePermissionPrompt": True,
            "enableAllProjectMcpServers": True,
            "permissions": {"defaultMode": "bypassPermissions",
                            "allow": ["Bash", "Bash(*)", "Bash(:*)", "Bash(git status)", "Read"]},
        })
        settings, status = self.apply_to(CLAUDE, ".claude/settings.json", live, parse=json.loads)
        self.assertIs(settings["skipDangerousModePermissionPrompt"], False)
        self.assertNotIn("enableAllProjectMcpServers", settings)
        self.assertEqual(settings["permissions"], {"allow": ["Bash(git status)", "Read"]})
        self.assertEqual(settings["hooks"]["SessionStart"][0]["hooks"][0]["command"], "x >/dev/null 2>&1")
        self.assertEqual(settings["env"], {"EXAMPLE": "keep"})
        self.assertEqual(settings["model"], "opus")
        self.assertEqual(status, "")

    def test_claude_keeps_safe_settings_byte_for_byte(self):
        live = '{"model": "sonnet", "permissions": {"defaultMode": "acceptEdits", "allow": ["Read"]},\n' \
               ' "skipDangerousModePermissionPrompt": false}\n'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source" / CLAUDE
            source.parent.mkdir(parents=True)
            source.write_bytes((ROOT / CLAUDE).read_bytes())
            target = root / "home/.claude/settings.json"
            target.parent.mkdir(parents=True)
            target.write_text(live)
            target.parent.chmod(0o700)
            target.chmod(0o600)
            (root / "config.toml").write_text("[data]\n")
            command = ["chezmoi", "--source", str(root / "source"), "--destination", str(root / "home"),
                       "--config", str(root / "config.toml"), "--persistent-state", str(root / "state")]
            env = {**os.environ, "HOME": str(root / "home")}
            self.assertEqual(subprocess.run(command + ["status"], env=env, check=True,
                                            capture_output=True, text=True).stdout, "")
            subprocess.run(command + ["apply", "--no-tty"], env=env, check=True, capture_output=True)
            self.assertEqual(target.read_text(), live)
            target.unlink()
            subprocess.run(command + ["apply", "--no-tty"], env=env, check=True, capture_output=True)
            created = json.loads(target.read_text())
            self.assertIs(created["skipDangerousModePermissionPrompt"], False)
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)


if __name__ == "__main__":
    unittest.main()
