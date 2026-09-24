#!/usr/bin/env python3
"""Regression checks for provider-compatible Hermes delegation defaults."""

from __future__ import annotations

import shutil
import subprocess
import os
import tempfile
import unittest
from pathlib import Path

import yaml


REPO_ROOT = Path(__file__).resolve().parents[1]
DATA_FILE = REPO_ROOT / ".chezmoidata.toml"
TEMPLATE_FILE = REPO_ROOT / ".chezmoiscripts" / "run_after_39-setup-hermes-agent.sh.tmpl"
README_FILE = REPO_ROOT / "README.md"
CONFIG_MODULE = REPO_ROOT / "dot_local/private_lib/chezmoi/hermes/config.sh"
CONFIG_WRITER = REPO_ROOT / "dot_local/private_lib/chezmoi/hermes/config.py"


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

        variables = (
            "HERMES_DELEGATION_PROVIDER", "HERMES_DELEGATION_MODEL",
            "HERMES_DELEGATION_REASONING_EFFORT",
        )
        for variable in variables:
            self.assertIn(f'{variable}=""', rendered, variable)
            self.assertIn(variable, CONFIG_MODULE.read_text(encoding="utf-8"))

        with tempfile.TemporaryDirectory() as directory:
            config_path = Path(directory) / "config.yaml"
            config_path.write_text("model: old/model\ndelegation:\n  provider: old\n  model: old\n  reasoning_effort: high\ncustom: keep\n")
            data = read_toml_section(DATA_FILE, "hermes.preferences")
            env = os.environ.copy()
            env.update({
                "HERMES_CONFIG_PATH": str(config_path),
                "HERMES_MODEL_PROVIDER": data["model_provider"],
                "HERMES_MODEL": data["model"],
                "HERMES_MODEL_BASE_URL": data["model_base_url"],
                "HERMES_SHOW_REASONING": data["show_reasoning"],
                "HERMES_REASONING_EFFORT": data["reasoning_effort"],
                "HERMES_SERVICE_TIER": data["service_tier"],
                "HERMES_AGENT_MAX_TURNS": data["agent_max_turns"],
                "HERMES_GOALS_MAX_TURNS": data["goals_max_turns"],
                "HERMES_CONTEXT_LENGTH": data["context_length"],
                **{variable: "" for variable in variables},
            })
            subprocess.run(["python3", str(CONFIG_WRITER)], env=env, check=True)
            first_bytes = config_path.read_bytes()
            first_mtime = config_path.stat().st_mtime_ns
            config = yaml.safe_load(first_bytes)
            self.assertEqual(config["delegation"], {"provider": "", "model": "", "reasoning_effort": ""})
            self.assertEqual(config["custom"], "keep")
            self.assertIs(config["display"]["show_reasoning"], True)
            self.assertIsInstance(config["agent"]["max_turns"], int)
            subprocess.run(["python3", str(CONFIG_WRITER)], env=env, check=True)
            self.assertEqual(config_path.read_bytes(), first_bytes)
            self.assertEqual(config_path.stat().st_mtime_ns, first_mtime)
            config_path.write_text("model: [bad\n")
            malformed = config_path.read_bytes()
            result = subprocess.run(["python3", str(CONFIG_WRITER)], env=env,
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(config_path.read_bytes(), malformed)
            self.assertIn("malformed Hermes YAML", result.stderr)
            config_path.write_text("model: []\n")
            incompatible = config_path.read_bytes()
            result = subprocess.run(["python3", str(CONFIG_WRITER)], env=env,
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(config_path.read_bytes(), incompatible)

    def test_managed_hermes_docs_do_not_promise_spark_delegation(self) -> None:
        readme = README_FILE.read_text(encoding="utf-8")
        self.assertNotIn("delegation.model=gpt-5.3-codex-spark", readme)
        self.assertNotIn("dedicated fast route instead of inheriting", readme)


if __name__ == "__main__":
    unittest.main()
