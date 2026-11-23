#!/usr/bin/env python3
"""Check the upstream skill sync against a local fixture repository, and its workflow."""

import contextlib
import importlib.util
import io
import os
from pathlib import Path
import re
import subprocess
import unittest

from lib.temp import temporary_directory

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/sync-upstream-skills.py"
SPEC = importlib.util.spec_from_file_location("sync_upstream_skills", SCRIPT)
sync = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sync)
WORKFLOW = ROOT / ".github/workflows/upstream-skills.yml"
REPO = "janestreet/agent_skills"
SKILL = "---\nname: \"tutor\"\ndescription: \"Teach.\"\n---\n\n# Tutor\n\nAsk questions.\n"
GIT_ENV = {**os.environ, "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1",
           "GIT_AUTHOR_NAME": "Test", "GIT_AUTHOR_EMAIL": "test@users.noreply.github.com",
           "GIT_COMMITTER_NAME": "Test", "GIT_COMMITTER_EMAIL": "test@users.noreply.github.com"}


def git(cwd, *args):
    return subprocess.run(["git", *args], cwd=cwd, env=GIT_ENV, capture_output=True,
                          text=True, check=True).stdout.strip()


class Fixture:
    def __init__(self, base):
        self.upstream = Path(base, "upstream")
        self.root = Path(base, "root")
        self.skills = self.root / sync.SKILLS
        self.skills.mkdir(parents=True)
        self.upstream.mkdir()
        git(self.upstream, "init", "--quiet", "--initial-branch=master")
        self.put({"LICENSE.md": "MIT License\n", "README.md": "Skills\n", "tutor/SKILL.md": SKILL})

    def put(self, files, message="change"):
        for name, text in files.items():
            path = self.upstream / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        git(self.upstream, "add", "--all")
        git(self.upstream, "commit", "--quiet", "-m", message)
        return git(self.upstream, "rev-parse", "HEAD")

    def run(self, *args):
        output = io.StringIO()
        argv = ["--root", str(self.root), "--clone-url", f"{REPO}={self.upstream}", *args]
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            status = sync.main(argv)
        return status, output.getvalue()

    def tree(self):
        return {path.relative_to(self.skills).as_posix(): path.read_text()
                for path in sorted(self.skills.rglob("*")) if path.is_file()}


class UpstreamSkillSyncTest(unittest.TestCase):
    def setUp(self):
        self.context = temporary_directory()
        self.fixture = Fixture(self.context.__enter__())
        self.addCleanup(self.context.__exit__, None, None, None)

    def test_new_skill_is_reported_then_written_with_its_pin_and_license(self):
        fixture = self.fixture
        commit = git(fixture.upstream, "rev-parse", "HEAD")
        status, output = fixture.run("--check")
        self.assertEqual(status, 1, output)
        self.assertIn("`tutor`: new", output)
        self.assertEqual(fixture.tree(), {})
        self.assertEqual(fixture.run()[0], 0)
        skill = (fixture.skills / "tutor/SKILL.md").read_text()
        self.assertIn(f"    commit: {commit}\n---\n", skill)
        self.assertIn(f"url: https://github.com/{REPO}/blob/master/tutor/SKILL.md", skill)
        self.assertTrue(skill.startswith("---\nname: \"tutor\"\ndescription: \"Teach.\"\nlicense: MIT\n"))
        self.assertEqual((fixture.skills / "tutor/LICENSE.txt").read_text(), "MIT License\n")
        self.assertEqual(fixture.run("--check")[0], 0)

    def test_commits_outside_the_skill_folder_keep_the_pin(self):
        fixture = self.fixture
        fixture.run()
        before = fixture.tree()
        fixture.put({"README.md": "More skills\n"})
        self.assertEqual(fixture.run("--check")[0], 0)
        self.assertEqual(fixture.tree(), before)

    def test_upstream_edit_is_reported_with_a_compare_link_and_then_synced(self):
        fixture = self.fixture
        fixture.run()
        old = git(fixture.upstream, "rev-parse", "HEAD")
        new = fixture.put({"tutor/SKILL.md": SKILL + "Check answers.\n",
                           "tutor/references/levels.md": "Levels\n"})
        before = fixture.tree()
        status, output = fixture.run("--check")
        self.assertEqual(status, 1, output)
        self.assertIn(f"https://github.com/{REPO}/compare/{old}...{new}", output)
        self.assertIn("added: `references/levels.md`", output)
        self.assertEqual(fixture.tree(), before)
        self.assertEqual(fixture.run()[0], 0)
        self.assertIn(f"commit: {new}", fixture.tree()["tutor/SKILL.md"])
        self.assertEqual(fixture.tree()["tutor/references/levels.md"], "Levels\n")
        git(fixture.upstream, "rm", "--quiet", "tutor/references/levels.md")
        git(fixture.upstream, "commit", "--quiet", "-m", "drop")
        fixture.run()
        self.assertNotIn("tutor/references/levels.md", fixture.tree())
        self.assertFalse((fixture.skills / "tutor/references").exists())

    def test_check_writes_the_report_file(self):
        report = self.fixture.root / "report.md"
        self.fixture.run("--check", "--report", str(report))
        self.assertIn("## Next steps", report.read_text())

    def test_skill_removed_upstream_is_reported_and_kept(self):
        fixture = self.fixture
        fixture.run()
        git(fixture.upstream, "rm", "--quiet", "-r", "tutor")
        git(fixture.upstream, "commit", "--quiet", "-m", "remove")
        status, output = fixture.run("--check")
        self.assertEqual(status, 1, output)
        self.assertIn("`tutor`: removed upstream", output)
        fixture.run()
        self.assertIn("tutor/SKILL.md", fixture.tree())

    def test_unsafe_upstream_content_stops_without_writing(self):
        cases = {
            "executable": lambda f: [(f.upstream / "tutor/run.sh").write_text("#!/bin/sh\n"),
                                     (f.upstream / "tutor/run.sh").chmod(0o755)],
            "symlink": lambda f: (f.upstream / "tutor/link.md").symlink_to("../README.md"),
            "chezmoi prefix": lambda f: (f.upstream / "tutor/dot_profile").write_text("x\n"),
            "template": lambda f: (f.upstream / "tutor/page.md.tmpl").write_text("x\n"),
            "hidden": lambda f: (f.upstream / "tutor/.env").write_text("x\n"),
            "own license key": lambda f: (f.upstream / "tutor/SKILL.md").write_text(
                SKILL.replace("---\n\n", "license: MIT\n---\n\n")),
            "no frontmatter": lambda f: (f.upstream / "tutor/SKILL.md").write_text("# Tutor\n"),
        }
        for name, change in cases.items():
            with self.subTest(name), temporary_directory() as base:
                fixture = Fixture(base)
                change(fixture)
                git(fixture.upstream, "add", "--all")
                git(fixture.upstream, "commit", "--quiet", "-m", name)
                status, output = fixture.run()
                self.assertEqual(status, 2, output)
                self.assertEqual(fixture.tree(), {})

    def test_the_vendored_tree_carries_the_source_pins(self):
        for source in sync.SOURCES:
            names = sync.tracked_local_names(ROOT, source)
            self.assertTrue(names, source["repo"])
            for name in names:
                files = sync.local_files(ROOT / sync.SKILLS / name)
                self.assertRegex(sync.pinned_commit(files) or "", r"^[0-9a-f]{40}$", name)
                self.assertIn("LICENSE.txt", files, name)


class UpstreamSkillWorkflowTest(unittest.TestCase):
    def setUp(self):
        self.text = WORKFLOW.read_text()

    def test_workflow_checks_only_and_writes_only_issues(self):
        self.assertIn("python3 -I scripts/sync-upstream-skills.py --check", self.text)
        self.assertNotRegex(self.text, r"sync-upstream-skills\.py(?![^\n]*--check)")
        writes = set(re.findall(r"(?m)^\s+([a-z-]+): write$", self.text))
        self.assertEqual(writes, {"issues"})
        self.assertIn("persist-credentials: false", self.text)

    def test_workflow_runs_on_a_schedule_from_the_default_branch(self):
        self.assertRegex(self.text, r"(?m)^  schedule:\n    - cron: '[0-9* ]+'$")
        self.assertIn("github.ref == format('refs/heads/{0}', github.event.repository.default_branch)",
                      self.text)

    def test_actions_are_pinned_to_commits(self):
        uses = re.findall(r"uses: (\S+)", self.text)
        self.assertTrue(uses)
        for action in uses:
            self.assertRegex(action, r"@[0-9a-f]{40}$")


if __name__ == "__main__":
    unittest.main()
