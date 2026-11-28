#!/usr/bin/env python3
"""Regression checks for canonical agent instructions and client safety."""

from __future__ import annotations

import json
import os
import re
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class AgentInstructionPolicyTest(unittest.TestCase):
    def test_claude_imports_only_the_canonical_root_guide(self) -> None:
        claude = (REPO_ROOT / "CLAUDE.md").read_text(encoding="utf-8")
        self.assertEqual(claude, "# CLAUDE.md\n\n@AGENTS.md\n")

    def test_guide_is_not_rendered_into_home(self) -> None:
        # A copy in ~ loads in every project under the home directory.
        targets = subprocess.check_output(
            ["chezmoi", "--source", str(REPO_ROOT), "managed", "--path-style=relative",
             "--exclude=externals,scripts"], text=True, timeout=60,
        ).splitlines()
        for target in ("AGENTS.md", "CLAUDE.md", ".codex/AGENTS.md"):
            self.assertNotIn(target, targets)

    def test_cleanup_removes_only_dotfiles_guide_copies(self) -> None:
        script = REPO_ROOT / ".chezmoiscripts/run_onchange_after_95-remove-home-agent-guides.sh"
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            (home / ".codex").mkdir()
            (home / "AGENTS.md").write_text(
                "# AGENTS.md\n\nAgent operating guide for this chezmoi dotfiles repository.\n")
            (home / "CLAUDE.md").write_text("# CLAUDE.md\n\n@AGENTS.md\n")
            user_guide = "# AGENTS.md\n\nMy own rules for every project.\n"
            (home / ".codex/AGENTS.md").write_text(user_guide)
            result = subprocess.run(["bash", str(script)], env={**os.environ, "HOME": str(home)},
                                    capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse((home / "AGENTS.md").exists())
            self.assertFalse((home / "CLAUDE.md").exists())
            self.assertEqual((home / ".codex/AGENTS.md").read_text(), user_guide)
            self.assertIn("Kept", result.stderr)

    def test_shared_guide_keeps_client_permission_policy(self) -> None:
        agents = (REPO_ROOT / "AGENTS.md").read_text(encoding="utf-8")
        self.assertIn("permission-prompt bypasses", agents)
        self.assertIn(".claude/settings.local.json", agents)
        self.assertIn("autoCommit", agents)
        self.assertIn("Prefer `jj`", agents)

    def test_tracked_claude_settings_keep_safety_prompts(self) -> None:
        template = (REPO_ROOT / "private_dot_claude/modify_private_settings.json").read_text(
            encoding="utf-8"
        )
        defaults = template.split("$defaults := `", 1)[1].split("`", 1)[0]
        settings = json.loads(defaults)
        self.assertIs(settings.get("skipDangerousModePermissionPrompt"), False)

    def test_repo_local_claude_allowlist_keeps_sandbox_prompts(self) -> None:
        settings = json.loads(
            (REPO_ROOT / ".claude/settings.local.json").read_text(encoding="utf-8")
        )
        sandbox = settings.get("sandbox", {})
        self.assertIs(sandbox.get("enabled"), True)
        self.assertIs(sandbox.get("autoAllowBashIfSandboxed"), False)


class ClaudeHarnessRulesTest(unittest.TestCase):
    """Rules that must not bend live in the harness, not only in AGENTS.md prose."""

    HOOKS = REPO_ROOT / ".claude/hooks"

    def settings(self) -> dict:
        return json.loads((REPO_ROOT / ".claude/settings.local.json").read_text(encoding="utf-8"))

    def test_irreversible_actions_are_denied(self) -> None:
        deny = self.settings()["permissions"]["deny"]
        for rule in ("Bash(git push *)", "Bash(jj git push *)", "Read(**/*.env)", "Read(**/.env.*)",
                     "Read(~/.config/dotfiles/*.env)", "Read(~/.ssh/id_*)"):
            self.assertIn(rule, deny)

    def test_read_deny_rules_use_forms_the_sandbox_enforces(self) -> None:
        template = (REPO_ROOT / "private_dot_claude/modify_private_settings.json").read_text(encoding="utf-8")
        managed = re.findall(r'"(Read\([^"]+\))"', template.split("$managedDeny := list", 1)[1].split("-}}", 1)[0])
        rules = [r for r in self.settings()["permissions"]["deny"] if r.startswith("Read(")] + managed
        self.assertGreater(len(managed), 0)
        for rule in rules:
            pattern = rule[len("Read("):-1].lstrip("!")
            with self.subTest(rule=rule):
                self.assertTrue(pattern.startswith(("**/", "~/", "//", "/")),
                                "A bare pattern such as *.env binds only the Read tool, not the sandbox; use **/*.env")

    def test_approval_rules_prompt_despite_broad_allows(self) -> None:
        ask = self.settings()["permissions"]["ask"]
        for rule in ("Bash(git reset --hard *)", "Bash(git checkout *)", "Bash(git restore *)",
                     "Bash(jj abandon *)", "Bash(jj restore *)", "Bash(chezmoi apply *)",
                     "Bash(rm -rf *)"):
            self.assertIn(rule, ask)

    def test_hooks_run_only_files_the_sandbox_cannot_write(self) -> None:
        hooks = self.settings()["hooks"]
        commands = [h["command"] for groups in hooks.values() for group in groups for h in group["hooks"]]
        pre = [h["command"] for group in hooks["PreToolUse"] if group["matcher"] == "Bash"
               for h in group["hooks"]]
        self.assertTrue(any("backup-before-risky.py" in command for command in pre))
        for command in commands:
            scripts = re.findall(r"\$CLAUDE_PROJECT_DIR/([^\"' ]+)", command)
            self.assertTrue(scripts, command)
            for script in scripts:
                self.assertTrue(script.startswith(".claude/hooks/"), command)
                self.assertTrue((REPO_ROOT / script).is_file(), script)
        source = (self.HOOKS / "backup-before-risky.py").read_text(encoding="utf-8")
        self.assertNotIn('"jj"', source)

    def run_backup(self, command: str, repo: Path, backups: Path) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["python3", "-I", str(self.HOOKS / "backup-before-risky.py")],
            input=json.dumps({"tool_input": {"command": command}}), capture_output=True, text=True,
            timeout=60, env={**os.environ, "CLAUDE_PROJECT_DIR": str(repo),
                             "DOTFILES_BACKUP_DIR": str(backups)},
        )

    def test_backup_hook_bundles_before_risky_commands_only(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo, backups = Path(directory) / "repo", Path(directory) / "backups"
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            subprocess.run(["git", "-C", str(repo), "-c", "user.name=t", "-c", "user.email=t@example.com",
                            "commit", "-q", "--allow-empty", "-m", "t"], check=True)
            (repo / "untracked.txt").write_text("unsaved work\n")
            risky = ["./tests/all", "cd x && bash tests/all", "chezmoi -S . apply",
                     "sudo ./scripts/bootstrap-omarchy.sh", "FOO=1 chezmoi update"]
            safe = ["git status", "chezmoi diff", "cat tests/all", "grep -r apply .chezmoiscripts/",
                    "chezmoi apply --dry-run --refresh-externals", "chezmoi -n apply"]
            for command in risky + safe:
                with self.subTest(command=command):
                    before = len(list(backups.glob("*.bundle"))) if backups.exists() else 0
                    result = self.run_backup(command, repo, backups)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    after = len(list(backups.glob("*.bundle"))) if backups.exists() else 0
                    self.assertEqual(after - before, 1 if command in risky else 0)
            restored = Path(directory) / "restored"
            newest = max(backups.glob("*.bundle"), key=lambda p: p.stat().st_mtime)
            subprocess.run(["git", "init", "-q", str(restored)], check=True)
            subprocess.run(["git", "-C", str(restored), "fetch", "-q", str(newest),
                            "refs/dotfiles-backup/working-tree"], check=True, capture_output=True)
            content = subprocess.run(["git", "-C", str(restored), "show", "FETCH_HEAD:untracked.txt"],
                                     capture_output=True, text=True, check=True).stdout
            self.assertEqual(content, "unsaved work\n")

    def test_backup_hook_runs_no_git_hook_files_and_keeps_bundles_private(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo, backups = Path(directory) / "repo", Path(directory) / "backups"
            marker = Path(directory) / "hook-ran"
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            subprocess.run(["git", "-C", str(repo), "-c", "user.name=t", "-c", "user.email=t@example.com",
                            "commit", "-q", "--allow-empty", "-m", "t"], check=True)
            hooks = repo / "planted-hooks"
            hooks.mkdir()
            for name in ("post-index-change", "reference-transaction"):
                (hooks / name).write_text(f"#!/bin/sh\necho {name} >> '{marker}'\n")
                (hooks / name).chmod(0o755)
            subprocess.run(["git", "-C", str(repo), "config", "core.hooksPath", "planted-hooks"], check=True)
            backups.mkdir(mode=0o755)
            backups.chmod(0o755)
            result = self.run_backup("./tests/all", repo, backups)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(marker.exists(), marker.read_text() if marker.exists() else "")
            self.assertEqual(backups.stat().st_mode & 0o777, 0o700)
            for bundle in backups.glob("*.bundle"):
                self.assertEqual(bundle.stat().st_mode & 0o077, 0)

    def test_backup_hook_blocks_when_the_bundle_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_backup("./tests/all", Path(directory) / "missing", Path(directory) / "b")
            self.assertEqual(result.returncode, 2)
            self.assertIn("Blocked", result.stderr)


def render(relative_path: str, role: str) -> str:
    return subprocess.check_output(
        ["chezmoi", "--source", str(REPO_ROOT), "execute-template"],
        input=(REPO_ROOT / relative_path).read_text(encoding="utf-8"),
        text=True, timeout=30, env={**os.environ, "CHEZMOI_ROLE": role},
    )


class ModernWebGuidancePinTest(unittest.TestCase):
    """The modern-web-guidance skill runs one pinned, offline copy on every workstation."""

    SKILL = REPO_ROOT / "private_dot_agents/private_skills/modern-web-guidance/SKILL.md"
    TARGET = ".local/share/modern-web-guidance"
    CLI = '"$HOME/.local/share/modern-web-guidance/skills/modern-web-guidance/modern-web.mjs"'

    def skill_parts(self) -> tuple[str, str]:
        _, frontmatter, body = self.SKILL.read_text(encoding="utf-8").split("---\n", 2)
        return frontmatter, body

    def external(self, role: str) -> dict | None:
        return tomllib.loads(render(".chezmoiexternal.toml.tmpl", role)).get(self.TARGET)

    def test_skill_never_runs_an_unpinned_package(self) -> None:
        _, body = self.skill_parts()
        bad = [line for line in body.splitlines()
               if re.search(r"\b(npx|pnpx|bunx)\b|@latest", line)]
        self.assertEqual(bad, [], "Run the pinned copy with node; see the 'Running the CLI' section.")

    def test_every_cli_call_uses_the_pinned_copy_with_telemetry_off(self) -> None:
        _, body = self.skill_parts()
        calls = [line for line in body.splitlines() if "modern-web.mjs" in line and " node " in f" {line}"]
        self.assertGreaterEqual(len(calls), 3)
        for line in calls:
            self.assertTrue(line.startswith(f"DISABLE_TELEMETRY=1 node {self.CLI} "), line)

    def test_external_is_checksummed_and_matches_the_skill_version(self) -> None:
        frontmatter, _ = self.skill_parts()
        version = re.search(r"npm-version: (\S+)", frontmatter).group(1)
        external = self.external("workstation")
        self.assertIsNotNone(external)
        self.assertEqual(external["url"],
                         f"https://registry.npmjs.org/modern-web-guidance/-/modern-web-guidance-{version}.tgz")
        self.assertRegex(external.get("checksum", {}).get("sha256", ""), r"^[0-9a-f]{64}$")

    def test_servers_get_neither_the_package_nor_the_skill(self) -> None:
        self.assertIsNone(self.external("server"))
        ignored = render(".chezmoiignore", "server").splitlines()
        self.assertIn(".agents/skills/modern-web-guidance", ignored)
        self.assertNotIn(".agents/skills/modern-web-guidance",
                         render(".chezmoiignore", "workstation").splitlines())


class ClientNeutralSkillTextTest(unittest.TestCase):
    """Claude, Codex, Pi, and Hermes all load the shared skill tree."""

    # Tool names that exist in only one client. Write "load the `<name>` skill"
    # or describe the action instead.
    CLIENT_ONLY = re.compile(r"\b(Skill tool|AskUserQuestion|TodoWrite|Task tool|ExitPlanMode)\b")

    def test_shared_skills_name_no_client_only_tools(self) -> None:
        root = REPO_ROOT / "private_dot_agents/private_skills"
        hits = [
            f"{path.relative_to(REPO_ROOT)}:{number}: {match.group(1)}"
            for path in sorted(root.rglob("*.md"))
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1)
            for match in [self.CLIENT_ONLY.search(line)] if match
        ]
        self.assertEqual(hits, [], "Use client-neutral wording, such as: load the `grill-me` skill.")


if __name__ == "__main__":
    unittest.main()
