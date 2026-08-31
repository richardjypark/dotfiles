#!/usr/bin/env python3
"""Regression checks for managed embedded-package source layout."""

from __future__ import annotations

import json
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PI_MAINTENANCE_DIR = REPO_ROOT / "dot_local/share/pi-maintenance-agent"


class ManagedPackageLayoutTest(unittest.TestCase):
    def test_pi_maintenance_npm_test_source_is_managed_with_package(self) -> None:
        package = json.loads(
            (PI_MAINTENANCE_DIR / "package.json").read_text(encoding="utf-8")
        )
        test_command = package["scripts"]["test"]
        self.assertEqual(test_command, "bash tests/e2e.sh")
        self.assertTrue((PI_MAINTENANCE_DIR / "tests/e2e.sh").is_file())

        ignore_lines = {
            line.strip()
            for line in (REPO_ROOT / ".chezmoiignore")
            .read_text(encoding="utf-8")
            .splitlines()
        }
        self.assertNotIn(".local/share/pi-maintenance-agent/tests", ignore_lines)

    def test_generated_pi_dependencies_remain_unmanaged(self) -> None:
        ignore_lines = {
            line.strip()
            for line in (REPO_ROOT / ".chezmoiignore")
            .read_text(encoding="utf-8")
            .splitlines()
        }
        self.assertIn(".local/share/pi-cli/node_modules", ignore_lines)
        self.assertIn(".local/share/pi-maintenance-agent/node_modules", ignore_lines)


if __name__ == "__main__":
    unittest.main()
