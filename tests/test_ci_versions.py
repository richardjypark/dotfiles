#!/usr/bin/env python3
"""Keep CI Go and Node versions on the repository's own pins."""

from pathlib import Path
import re
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]


def workflow_values(key):
    return sorted((path.name, value) for path in (ROOT / ".github/workflows").glob("*.yml")
                  for value in re.findall(rf"(?m)^\s+{key}:\s*'?([^'\s#]+)'?", path.read_text()))


class CiVersionTest(unittest.TestCase):
    def test_workflows_use_the_pinned_go_minor_line(self):
        pinned = tomllib.loads((ROOT / ".chezmoidata.toml").read_text())["pinned"]["go"]["version"]
        minor = re.fullmatch(r"go(\d+\.\d+)\.\d+", pinned).group(1)
        values = workflow_values("go-version")
        self.assertTrue(values)
        self.assertEqual({value for _, value in values}, {minor}, values)

    def test_workflows_use_the_pinned_mise_node(self):
        mise = (ROOT / "private_dot_config/mise/modify_config.toml").read_text()
        pinned = re.findall(r'(?m)^node = "([0-9.]+)"$', mise)
        self.assertEqual(len(pinned), 1)
        values = workflow_values("node-version")
        self.assertTrue(values)
        self.assertEqual({value for _, value in values}, set(pinned), values)


if __name__ == "__main__":
    unittest.main()
