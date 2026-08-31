#!/usr/bin/env python3
"""Regression checks for canonical agent instructions and client safety."""

from __future__ import annotations

import json
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
        settings = json.loads(
            (REPO_ROOT / "private_dot_claude/settings.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertIs(settings.get("skipDangerousModePermissionPrompt"), False)

    def test_repo_local_claude_allowlist_keeps_sandbox_prompts(self) -> None:
        settings = json.loads(
            (REPO_ROOT / ".claude/settings.local.json").read_text(encoding="utf-8")
        )
        sandbox = settings.get("sandbox", {})
        self.assertIs(sandbox.get("enabled"), True)
        self.assertIs(sandbox.get("autoAllowBashIfSandboxed"), False)


if __name__ == "__main__":
    unittest.main()
