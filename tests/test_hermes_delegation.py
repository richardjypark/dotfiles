#!/usr/bin/env python3
"""Regression checks for provider-compatible Hermes delegation defaults."""

from __future__ import annotations

import shutil
import subprocess
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DATA_FILE = REPO_ROOT / ".chezmoidata.toml"
TEMPLATE_FILE = REPO_ROOT / ".chezmoiscripts" / "run_after_39-setup-hermes-agent.sh.tmpl"
README_FILE = REPO_ROOT / "README.md"


def read_toml_section(path: Path, section: str) -> dict[str, str]:
    values: dict[str, str] = {}
    in_section = False
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line == f"[{section}]":
            in_section = True
            continue
        if in_section and line.startswith("["):
            break
        if not in_section or not line or line.startswith("#"):
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"')
    return values


class HermesDelegationDefaultsTest(unittest.TestCase):
    def test_tracked_delegation_defaults_inherit_parent(self) -> None:
        self.assertEqual(
            read_toml_section(DATA_FILE, "hermes.delegation"),
            {"provider": "", "model": "", "reasoning_effort": ""},
        )

    @unittest.skipUnless(shutil.which("chezmoi"), "chezmoi is required to render templates")
    def test_rendered_setup_actively_clears_delegation_overrides(self) -> None:
        rendered = subprocess.run(
            ["chezmoi", "--source", str(REPO_ROOT), "execute-template"],
            input=TEMPLATE_FILE.read_text(encoding="utf-8"),
            capture_output=True,
            check=True,
            text=True,
        ).stdout

        variables = {
            "HERMES_DELEGATION_PROVIDER": "delegation.provider",
            "HERMES_DELEGATION_MODEL": "delegation.model",
            "HERMES_DELEGATION_REASONING_EFFORT": "delegation.reasoning_effort",
        }
        for variable, config_key in variables.items():
            self.assertIn(f'{variable}=""', rendered, variable)
            self.assertIn(
                f'config set {config_key} "${variable}"',
                rendered,
            )

    def test_managed_hermes_docs_do_not_promise_spark_delegation(self) -> None:
        readme = README_FILE.read_text(encoding="utf-8")
        self.assertNotIn("delegation.model=gpt-5.3-codex-spark", readme)
        self.assertNotIn("dedicated fast route instead of inheriting", readme)


if __name__ == "__main__":
    unittest.main()
