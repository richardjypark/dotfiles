#!/usr/bin/env python3
"""Regression checks for canonical agent instructions and client safety."""

from __future__ import annotations

import json
import os
import re
import subprocess
import tomllib
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class AgentInstructionPolicyTest(unittest.TestCase):
    def test_claude_imports_only_the_canonical_root_guide(self) -> None:
        claude = (REPO_ROOT / "CLAUDE.md").read_text(encoding="utf-8")
        self.assertEqual(claude, "# CLAUDE.md\n\n@AGENTS.md\n")

    def test_codex_imports_the_canonical_root_guide(self) -> None:
        codex = (REPO_ROOT / "private_dot_codex/AGENTS.md.tmpl").read_text(
            encoding="utf-8"
        )
        self.assertEqual(codex, '{{ include "AGENTS.md" }}\n')

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
