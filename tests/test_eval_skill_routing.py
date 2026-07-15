from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "scripts" / "eval-skill-routing.py"
SPEC = importlib.util.spec_from_file_location("eval_skill_routing", SCRIPT_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load {SCRIPT_PATH}")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ParseSkillTests(unittest.TestCase):
    def test_parse_skill_uses_only_top_level_frontmatter_fields(self) -> None:
        content = """---
name: outer-skill
description: "Top-level description"
metadata:
  name: nested-name
  description: nested description
---

# Body
"""
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "SKILL.md"
            path.write_text(content, encoding="utf-8")

            skill = MODULE.parse_skill(path)

        self.assertEqual(
            skill,
            {"name": "outer-skill", "description": "Top-level description"},
        )


class ValidateCasesTests(unittest.TestCase):
    def setUp(self) -> None:
        self.catalog = [
            {"name": "alpha", "description": "Alpha work"},
            {"name": "beta", "description": "Beta work"},
        ]

    def test_validate_cases_requires_each_skill_and_one_none_control(self) -> None:
        payload = {
            "cases": [
                {"id": "a", "request": "alpha request", "expected_skill": "alpha"},
                {"id": "b", "request": "beta request", "expected_skill": "beta"},
                {"id": "n", "request": "unrelated request", "expected_skill": "none"},
            ]
        }

        cases = MODULE.validate_cases(payload, self.catalog)

        self.assertEqual(cases, payload["cases"])

    def test_validate_cases_rejects_incomplete_inventory(self) -> None:
        payload = {
            "cases": [
                {"id": "a", "request": "alpha request", "expected_skill": "alpha"},
                {"id": "n", "request": "unrelated request", "expected_skill": "none"},
            ]
        }

        with self.assertRaisesRegex(MODULE.HarnessError, "coverage"):
            MODULE.validate_cases(payload, self.catalog)


class ExtractPayloadTests(unittest.TestCase):
    def test_extract_payload_tolerates_ansi_reasoning_and_session_prefix(self) -> None:
        output = """\x1b[36mReasoning\x1b[0m
classification complete
session_id: 20260715_example
```json
{"results":[{"id":"a","skill":"alpha"}]}
```
"""

        payload = MODULE.extract_payload(output)

        self.assertEqual(
            payload,
            {"results": [{"id": "a", "skill": "alpha"}]},
        )


if __name__ == "__main__":
    unittest.main()
