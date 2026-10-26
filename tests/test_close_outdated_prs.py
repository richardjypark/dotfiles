#!/usr/bin/env python3
"""Check which open pull requests the outdated-PR cleanup closes, and how it closes them."""

from datetime import datetime, timedelta, timezone
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import unittest
from unittest import mock

from lib.temp import temporary_directory

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/close-outdated-prs.py"
SPEC = importlib.util.spec_from_file_location("close_outdated_prs", SCRIPT)
cleanup = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cleanup)
NOW = datetime(2026, 10, 25, 12, tzinfo=timezone.utc)
GIT_ENV = {"GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1", "GIT_AUTHOR_NAME": "Test",
           "GIT_AUTHOR_EMAIL": "test@users.noreply.github.com", "GIT_COMMITTER_NAME": "Test",
           "GIT_COMMITTER_EMAIL": "test@users.noreply.github.com"}


def git(cwd, *args):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=True).stdout.strip()


def commit(work, name, text):
    Path(work, name).write_text(text)
    git(work, "add", name)
    git(work, "commit", "--quiet", "-m", f"set {name}")
    return git(work, "rev-parse", "HEAD")


def pr(number, head, days_old=1, labels=(), author="octocat"):
    stamp = (NOW - timedelta(days=days_old)).isoformat().replace("+00:00", "Z")
    return {"number": number, "title": f"PR {number}", "head": {"sha": head}, "base": {"ref": "master"},
            "updated_at": stamp, "labels": [{"name": label} for label in labels], "state": "open",
            "user": {"login": author}}


class ReviewTest(unittest.TestCase):
    def test_superseded_and_inactive_pull_requests_are_outdated(self):
        with temporary_directory() as tmp, mock.patch.dict(os.environ, GIT_ENV):
            origin, work, source = (str(Path(tmp, name)) for name in ("origin.git", "work", "source"))
            git(tmp, "init", "--quiet", "--bare", "-b", "master", origin)
            git(origin, "config", "uploadpack.allowAnySHA1InWant", "true")  # GitHub serves PR heads by SHA.
            git(tmp, "init", "--quiet", "-b", "master", work)
            git(work, "remote", "add", "origin", origin)
            start = commit(work, "a.txt", "one\n")
            landed = commit(work, "a.txt", "two\n")
            git(work, "checkout", "--quiet", "-b", "fresh", start)
            fresh = commit(work, "c.txt", "new\n")
            git(work, "checkout", "--quiet", "-b", "conflict", start)
            conflict = commit(work, "a.txt", "three\n")
            git(work, "checkout", "--quiet", "-B", "master", start)
            commit(work, "a.txt", "two\n")  # The same change lands through another commit.
            commit(work, "b.txt", "later\n")
            git(work, "push", "--quiet", "origin", "master", "fresh", "conflict", f"{landed}:refs/heads/landed")
            git(tmp, "clone", "--quiet", origin, source)

            prs = [pr(1, landed), pr(2, landed, labels=[cleanup.KEEP_LABEL]), pr(3, fresh),
                   pr(4, fresh, days_old=30), pr(5, conflict), pr(6, conflict, days_old=45),
                   pr(7, fresh, days_old=45, author=cleanup.DEPENDABOT), pr(8, landed, author=cleanup.DEPENDABOT)]
            rows = cleanup.review(source, "owner/repo", prs, NOW, 30, apply=False)

        self.assertEqual([result for _, _, result in rows],
                         ["would close: superseded", "kept", "kept", "would close: inactive",
                          "kept", "would close: inactive", "kept", "would close: superseded"])

    def test_no_open_pull_requests_needs_no_fetch(self):
        with mock.patch.object(cleanup, "fetch", side_effect=AssertionError("unexpected fetch")):
            self.assertEqual(cleanup.review(".", "owner/repo", [], NOW, 30, apply=True), [])
        self.assertIn("No open pull requests.", cleanup.summary([], apply=True))


class OpenPullRequestsTest(unittest.TestCase):
    def open_prs(self, *heads):
        pages = json.dumps([[pr(number, head) for number, head in enumerate(heads, 1)]])
        with mock.patch.object(cleanup, "run", return_value=pages):
            return cleanup.open_prs("owner/repo")

    def test_head_commits_must_be_full_object_ids(self):
        self.assertEqual([row["head"]["sha"] for row in self.open_prs("a" * 40)], ["a" * 40])
        with self.assertRaisesRegex(SystemExit, "#2 has an invalid head commit"):
            self.open_prs("a" * 40, "--upload-pack=touch x")


class CloseTest(unittest.TestCase):
    def close(self, current, why="superseded"):
        calls = []

        def api(path, method="GET", fields=None):
            calls.append((path, method, fields))
            return current if method == "GET" else {}

        with mock.patch.object(cleanup, "api", api):
            result = cleanup.close("owner/repo", pr(7, "a" * 40), why, 30)
        return result, calls

    def test_close_then_explain_the_reason(self):
        result, calls = self.close(pr(7, "a" * 40))
        self.assertEqual(result, "closed: superseded")
        self.assertEqual([(path, method) for path, method, _ in calls],
                         [("repos/owner/repo/pulls/7", "GET"), ("repos/owner/repo/pulls/7", "PATCH"),
                          ("repos/owner/repo/issues/7/comments", "POST")])
        self.assertEqual(calls[1][2], {"state": "closed"})
        self.assertIn("The `master` branch already contains every change", calls[2][2]["body"])
        self.assertIn("`keep-open` label", calls[2][2]["body"])

    def test_inactive_reason_names_the_threshold(self):
        _, calls = self.close(pr(7, "a" * 40), why="inactive")
        self.assertIn("no activity for 30 days", calls[2][2]["body"])

    def test_pull_request_that_changed_during_the_check_stays_open(self):
        for current in (pr(7, "b" * 40), pr(7, "a" * 40, days_old=0), {**pr(7, "a" * 40), "state": "closed"}):
            result, calls = self.close(current)
            self.assertEqual(result, "kept: it changed during the check")
            self.assertEqual([method for _, method, _ in calls], ["GET"])


class SummaryTest(unittest.TestCase):
    def test_titles_cannot_break_the_table_or_add_markup(self):
        report = cleanup.summary([(8, "a | b <img src=x>", "kept")], apply=False)
        self.assertIn("Mode: report only", report)
        self.assertIn("| #8 | a \\| b &lt;img src=x&gt; | kept |", report)


if __name__ == "__main__":
    unittest.main()
