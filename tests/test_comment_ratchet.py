#!/usr/bin/env python3
"""The comment ratchet counts real comments only, and the repo stays at its baseline."""

import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/comment-ratchet.py"
spec = importlib.util.spec_from_file_location("comment_ratchet", SCRIPT)
ratchet = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ratchet)


def counted(path, text):
    return [number for number, _ in ratchet.comments(path, text)]


class CommentDetection(unittest.TestCase):
    def test_shell_own_line_and_trailing_comments_count(self):
        text = "#!/usr/bin/env bash\n# own\nx=1  # trailing\necho '# quoted' \"# too\"\n"
        self.assertEqual(counted("scripts/a.sh", text), [2, 3])

    def test_shell_heredoc_bodies_are_content(self):
        text = "cat > f <<'EOF'\n# written to f\nEOF\n# after\ncat <<-END\n\t# also content\n\tEND\n"
        self.assertEqual(counted("scripts/a.sh", text), [4])

    def test_shell_parameter_expansions_are_not_comments(self):
        text = 'n=${#list[@]}\nm=$#\ny="${x#v}"\n'
        self.assertEqual(counted("scripts/a.sh", text), [])

    def test_pragmas_and_template_hash_triggers_are_exempt(self):
        text = "#!/bin/sh\n# shellcheck disable=SC1090\n# Units: {{ include \"a\" | sha256sum }}\n# real\n"
        self.assertEqual(counted(".chezmoiscripts/run_after_x.sh.tmpl", text), [4])

    def test_python_uses_tokens_so_strings_with_hash_do_not_count(self):
        text = "x = '# not'  # yes\n# own\ny = 1  # noqa: E501\n"
        self.assertEqual(counted("scripts/a.py", text), [1, 2])

    def test_typescript_line_block_and_trailing_comments_count(self):
        text = "// a\n/**\n * b\n */\nconst u = 'http://x';\nf(); // c\n// @ts-expect-error\n"
        self.assertEqual(counted("dot_pi/agent/extensions/a.ts", text), [1, 2, 3, 4, 6])

    def test_language_comes_from_the_shebang_when_there_is_no_extension(self):
        self.assertEqual(ratchet.language("dot_local/bin/executable_x", "#!/usr/bin/env python3\n"), "py")
        self.assertEqual(ratchet.language("tests/all", "#!/usr/bin/env bash\n"), "sh")
        self.assertIsNone(ratchet.language("dot_local/bin/executable_x", "plain text\n"))

    def test_scope_skips_examples_and_third_party_code(self):
        self.assertTrue(ratchet.in_scope("dot_local/bin/executable_czm"))
        self.assertFalse(ratchet.in_scope("scripts/bootstrap-private-env.example"))
        self.assertFalse(ratchet.in_scope("dot_pi/agent/extensions/subagent/index.ts"))
        self.assertFalse(ratchet.in_scope("private_dot_agents/private_skills/tdd/SKILL.md"))
        self.assertFalse(ratchet.in_scope("dot_tmux.conf"))


class RepositoryBaseline(unittest.TestCase):
    def test_repository_matches_its_baseline(self):
        result = subprocess.run([sys.executable, str(SCRIPT), "--check"], capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
