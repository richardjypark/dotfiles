#!/usr/bin/env python3
"""Check the Dependabot auto-merge eligibility rules and the workflow that applies them."""

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import unittest

from lib.temp import temporary_directory

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("auto_merge", ROOT / "scripts/dependabot-auto-merge.py")
auto = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(auto)
REPO = "owner/dotfiles"
GO_MOD = """module dotfiles/ci-tools

go 1.26.0

require (
\tgithub.com/rhysd/actionlint v1.7.12
\tgithub.com/zricethezav/gitleaks/v8 v8.30.1
)

require (
\tgithub.com/klauspost/compress v1.18.7 // indirect
\tgo.yaml.in/yaml/v4 v4.0.0-rc.3 // indirect
)
"""


def package(**dependencies):
    return json.dumps({"name": "agent", "private": True,
                       "dependencies": {"@openrouter/agent": "1.2.1", "glob": "14.0.6", **dependencies},
                       "devDependencies": {"typescript": "7.0.2"}}, indent=2) + "\n"


def commit(sha="a" * 40, author=auto.BOT, committer=auto.COMMITTER, verified=True, parents=("0" * 40,)):
    return {"sha": sha, "author": {"login": author}, "committer": {"login": committer},
            "parents": [{"sha": parent} for parent in parents], "commit": {"verification": {"verified": verified}}}


def pull_request(head_sha, **changes):
    pr = {"state": "open", "draft": False, "user": {"login": auto.BOT}, "head": {"sha": head_sha, "repo": {"full_name": REPO}},
          "base": {"ref": "main"}, "auto_merge": None}
    pr.update(changes)
    return pr


class VersionRules(unittest.TestCase):
    def test_patch_and_minor_updates_are_allowed(self):
        for old, new in (("14.0.3", "14.0.6"), ("1.2.1", "1.3.0"), ("v8.30.1", "v8.31.0"), ("^1.5.85", "^1.5.90"), ("0.13.1", "0.13.4")):
            auto.check_version("dep", old, new)

    def test_majors_zero_minors_downgrades_and_prereleases_are_refused(self):
        for old, new in (("1.2.1", "2.0.0"), ("0.11.0", "0.12.0"), ("1.3.0", "1.2.9"), ("v4.0.0-rc.3", "v4.0.0-rc.4"),
                         ("^1.5.85", "~1.5.90"), ("1.2.1", "latest"), ("v0.0.2-0.2023", "v0.0.2-0.2024")):
            with self.subTest(old=old, new=new), self.assertRaises(ValueError):
                auto.check_version("dep", old, new)


class ManifestRules(unittest.TestCase):
    def test_npm_version_changes_are_listed(self):
        self.assertEqual(auto.npm_changes(package(), package(glob="14.0.7")), [("glob", "14.0.6", "14.0.7")])

    def test_npm_refuses_added_dependencies_and_other_fields(self):
        with self.assertRaises(ValueError):
            auto.npm_changes(package(), package(leftpad="1.0.0"))
        changed = json.loads(package())
        changed["scripts"] = {"postinstall": "curl example.invalid | sh"}
        with self.assertRaises(ValueError):
            auto.npm_changes(package(), json.dumps(changed))

    def test_go_version_changes_are_listed(self):
        new = GO_MOD.replace("compress v1.18.7", "compress v1.18.8")
        self.assertEqual(auto.go_changes(GO_MOD, new), [("github.com/klauspost/compress", "v1.18.7", "v1.18.8")])

    def test_go_refuses_directive_module_marker_and_comment_changes(self):
        for new in (GO_MOD.replace("go 1.26.0", "go 1.27.0"),
                    GO_MOD.replace("\tgo.yaml.in", "\texample.com/new v1.0.0 // indirect\n\tgo.yaml.in"),
                    GO_MOD.replace("compress v1.18.7 // indirect", "compress v1.18.7"),
                    GO_MOD.replace("actionlint v1.7.12", "actionlint v1.7.13 // pinned")):
            with self.subTest(new=new), self.assertRaises(ValueError):
                auto.go_changes(GO_MOD, new)


class PullRequestRules(unittest.TestCase):
    def test_only_open_dependabot_pull_requests_from_this_repository_pass(self):
        auto.check_pull_request(pull_request("b" * 40), REPO, "main", "b" * 40)
        for pr, head in ((pull_request("b" * 40, user={"login": "someone"}), "b" * 40),
                         (pull_request("b" * 40, head={"sha": "b" * 40, "repo": {"full_name": "fork/dotfiles"}}), "b" * 40),
                         (pull_request("b" * 40, head={"sha": "b" * 40, "repo": None}), "b" * 40),
                         (pull_request("b" * 40, base={"ref": "dev"}), "b" * 40),
                         (pull_request("b" * 40, draft=True), "b" * 40),
                         (pull_request("b" * 40), "c" * 40)):
            with self.subTest(pr=pr, head=head), self.assertRaises(ValueError):
                auto.check_pull_request(pr, REPO, "main", head)

    def test_commits_are_verified_dependabot_commits_or_default_branch_merges(self):
        on_main = {"m" * 40}.__contains__
        update_branch = commit("b" * 40, author="owner", parents=("a" * 40, "m" * 40))
        auto.check_commits([commit(), commit("c" * 40)], on_main)
        auto.check_commits([commit(), update_branch], on_main)
        for commits in ([], [update_branch], [commit(), commit(author="someone")],
                        [commit(), commit(author="owner", parents=("a" * 40, "x" * 40))],
                        [commit(committer="someone")], [commit(verified=False)]):
            with self.subTest(commits=commits), self.assertRaises(ValueError):
                auto.check_commits(commits, on_main)


class Evaluate(unittest.TestCase):
    def setUp(self):
        context = temporary_directory()
        self.source = Path(context.__enter__())
        self.addCleanup(context.__exit__, None, None, None)
        self.env = {**os.environ, "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1",
                    "GIT_AUTHOR_NAME": "test", "GIT_COMMITTER_NAME": "test",
                    "GIT_AUTHOR_EMAIL": "test@users.noreply.github.com", "GIT_COMMITTER_EMAIL": "test@users.noreply.github.com"}
        self.git("init", "-q", "-b", "main")
        self.write(auto.NPM_MANIFEST, package())
        self.write("dot_local/share/openrouter-agent/package-lock.json", "{}\n")
        self.write(auto.GO_MANIFEST, GO_MOD)
        self.write("README.md", "readme\n")
        self.base = self.commit("base")

    def git(self, *args):
        result = subprocess.run(["git", "-C", str(self.source), *args], env=self.env, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def write(self, path, text):
        target = self.source / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)

    def commit(self, message):
        self.git("add", "-A")
        self.git("commit", "-qm", message)
        return self.git("rev-parse", "HEAD").strip()

    def evaluate(self, head):
        return auto.evaluate(self.source, REPO, "main", pull_request(head), [commit(head)], self.base, head)

    def test_a_grouped_patch_update_is_eligible(self):
        self.write(auto.NPM_MANIFEST, package(glob="14.0.7"))
        self.write("dot_local/share/openrouter-agent/package-lock.json", '{"changed": true}\n')
        self.write(auto.GO_MANIFEST, GO_MOD.replace("actionlint v1.7.12", "actionlint v1.8.0"))
        head = self.commit("bump")
        self.assertEqual(self.evaluate(head), [("glob", "14.0.6", "14.0.7"),
                                               ("github.com/rhysd/actionlint", "v1.7.12", "v1.8.0")])

    def test_files_outside_the_scope_are_refused(self):
        self.write(auto.NPM_MANIFEST, package(glob="14.0.7"))
        self.write("README.md", "changed\n")
        with self.assertRaisesRegex(ValueError, "outside the auto-merge scope: README.md"):
            self.evaluate(self.commit("bump"))

    def test_lockfile_only_and_major_updates_are_refused(self):
        self.write("dot_local/share/openrouter-agent/package-lock.json", '{"changed": true}\n')
        with self.assertRaisesRegex(ValueError, "lockfile-only"):
            self.evaluate(self.commit("lock"))
        self.write(auto.NPM_MANIFEST, package(**{"@openrouter/agent": "2.0.0"}))
        with self.assertRaisesRegex(ValueError, "major update"):
            self.evaluate(self.commit("major"))


class Workflow(unittest.TestCase):
    def test_workflow_runs_trusted_code_for_dependabot_only(self):
        workflow = (ROOT / ".github/workflows/dependabot-auto-merge.yml").read_text()
        self.assertIn("pull_request_target:", workflow)
        self.assertIn("github.event.pull_request.user.login == 'dependabot[bot]'", workflow)
        self.assertIn("github.event.pull_request.head.repo.full_name == github.repository", workflow)
        self.assertIn("ref: ${{ github.sha }}", workflow)
        self.assertIn("persist-credentials: false", workflow)
        self.assertNotIn("github.actor", workflow)
        self.assertNotIn("secrets.", workflow)
        self.assertNotIn("pull_request.head.ref", workflow)
        self.assertNotRegex(workflow, r"ref:\s*\$\{\{\s*github\.event\.pull_request\.head")
        script = (ROOT / "scripts/dependabot-auto-merge.py").read_text()
        self.assertIn('"--match-head-commit", args.head', script)
        self.assertIn("publisher.require_merge_rules(", script)


if __name__ == "__main__":
    unittest.main()
