#!/usr/bin/env python3
"""Offline candidate, branch race, credential-boundary and real JJ regressions."""

import base64
from copy import deepcopy
from datetime import datetime, timedelta, timezone
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tarfile
import unittest
from unittest.mock import patch

from lib.temp import temporary_directory

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


candidate = load("candidate_test", ROOT / "scripts/check-maintenance-candidate.py")
publisher = load("publisher_test", ROOT / "scripts/publish-maintenance-candidate.py")
REPO = "owner/dotfiles"
LOGIN = "maintenance-test[bot]"
RUN = "123"
HASH = "1" * 64


class Fixture(unittest.TestCase):
    def setUp(self):
        context = temporary_directory()
        self.temp = Path(context.__enter__())
        self.addCleanup(context.__exit__, None, None, None)
        self.source = self.temp / "source"
        self.source.mkdir()
        self.bin = self.temp / "bin"
        self.bin.mkdir()
        config = self.temp / "jj-config.toml"
        config.write_text('[user]\nname = "test"\nemail = "test@users.noreply.github.com"\n')
        self.env = {**os.environ, "HOME": str(self.temp), "XDG_STATE_HOME": str(self.temp / "state"),
                    "XDG_CONFIG_HOME": str(self.temp / "config"), "JJ_CONFIG": str(config),
                    "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1",
                    "GIT_AUTHOR_NAME": "test", "GIT_COMMITTER_NAME": "test",
                    "GIT_AUTHOR_EMAIL": "test@users.noreply.github.com", "GIT_COMMITTER_EMAIL": "test@users.noreply.github.com",
                    "PATH": f"{self.bin}{os.pathsep}{os.environ['PATH']}", "CHEZMOI_AUTOMATIC_UPDATES": "0"}
        environment = patch.dict(os.environ, self.env)
        environment.start()
        self.addCleanup(environment.stop)
        for path in (*candidate.PATHS, ".gitignore", "scripts/check-public-files.py",
                     "dot_local/bin/executable_dotfiles-push", "dot_local/bin/executable_dotfiles-secret-scan"):
            destination = self.source / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / path, destination)
        self.git("init", "-q", "-b", "main")
        self.git("add", "--", *candidate.PATHS, ".gitignore", "scripts", "dot_local/bin")
        self.git("commit", "-qm", "test: fixture")
        self.base = self.git("rev-parse", "HEAD").strip()
        self.git("remote", "add", "origin", f"https://github.com/{REPO}.git")
        self.git("update-ref", "refs/remotes/origin/main", self.base)
        self.before = {path: (self.source / path).read_bytes() for path in candidate.PATHS}
        self.contracts = candidate.inventory()
        self.old = candidate.parse_pins(self.before, self.contracts)[0]["pinned"]["jj"]["version"]
        raw = self.old.removeprefix("v").split(".")
        self.new = "v" + ".".join((*raw[:2], str(int(raw[2]) + 1)))

    def git(self, *args):
        result = subprocess.run(["git", "-C", str(self.source), *args], env=self.env, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def after(self):
        # Independent fixture edits, rather than the production replacement function.
        data = self.before[candidate.PATHS[0]].decode()
        old_pin = candidate.parse_pins(self.before, self.contracts)[0]["pinned"]["jj"]
        data = data.replace('version = "' + self.old + '"', 'version = "' + self.new + '"')
        for key in candidate.KEYS:
            data = data.replace(key + ' = "' + old_pin[key] + '"', key + ' = "' + HASH + '"')
        versions = self.before[candidate.PATHS[1]].decode().replace('jj = "' + self.old + '"', 'jj = "' + self.new + '"')
        return {candidate.PATHS[0]: data.encode(), candidate.PATHS[1]: versions.encode()}

    def metadata(self):
        return [{"tag_name": self.new, "published_at": (datetime.now(timezone.utc) - timedelta(days=8)).isoformat(),
                 "draft": False, "prerelease": False,
                 "assets": [{"name": name, "digest": "sha256:" + HASH} for name in candidate.stable.release_assets("jj", self.new)]}]

    def bundle(self):
        for path, data in self.after().items():
            (self.source / path).write_bytes(data)
        old_data = candidate.parse_pins(self.before, self.contracts)[0]
        rows = [{"name": name, "source": self.contracts[name]["source"], "current": old_data["pinned"][name]["version"],
                 "state": "eligible" if name == "jj" else "current", "candidate": self.new if name == "jj" else ""} for name in candidate.TOOLS]
        report = self.temp / "report.json"
        report.write_text(json.dumps({"schema": 1, "dependencies": rows}))
        with patch.object(candidate.stable, "github_rows", return_value=self.metadata()):
            result = candidate.build_bundle(self.source, self.base, REPO, RUN, "1", report)
        for path, data in self.before.items():
            (self.source / path).write_bytes(data)
        return result

    def validate(self, data, **kwargs):
        return candidate.validate_bundle(data, self.source, self.base, REPO, RUN, "1", **kwargs)

    def tool(self, name, body):
        target = self.bin / name
        target.write_text(body)
        target.chmod(0o755)


class CandidateTests(Fixture):
    def test_empty_routine_pr_is_rejected_but_normal_pr_can_pass(self):
        args = ["check-maintenance-candidate.py", "diff", "--source", str(self.source),
                "--base", self.base, "--head", self.base]
        with patch.object(sys, "argv", args + ["--routine"]), patch("sys.stderr", new_callable=io.StringIO) as error:
            self.assertEqual(candidate.main(), 1)
            self.assertIn("no patch changes", error.getvalue())
        with patch.object(sys, "argv", args), patch("sys.stdout", new_callable=io.StringIO):
            self.assertEqual(candidate.main(), 0)

    def test_round_trip_and_fresh_metadata(self):
        bundle = self.bundle()
        after, changes = self.validate(bundle)
        self.assertEqual(after, self.after())
        self.assertEqual(changes, [{"name": "jj", "current": self.old, "target": self.new}])
        with patch.object(candidate.stable, "github_rows", return_value=self.metadata()):
            # Use the same publication stamp from the candidate for exact revalidation.
            rows = self.metadata()
            rows[0]["published_at"] = bundle["dependencies"][0]["publishedAt"]
            with patch.object(candidate.stable, "github_rows", return_value=rows):
                self.validate(bundle, online=True)

    def test_unrelated_changes_and_nonpatch_updates_are_rejected(self):
        for edit in (lambda text: text + b"\n# unrelated comment\n",
                     lambda text: text.replace(b'name = "rich"', b'name = "other"'),
                     lambda text: text.replace(b'reasoning_effort = "xhigh"', b'reasoning_effort = "low"'),
                     lambda text: text.replace(self.new.encode(), b"v9.0.0")):
            with self.subTest(edit=edit):
                after = self.after()
                after[candidate.PATHS[0]] = edit(after[candidate.PATHS[0]])
                with self.assertRaises(ValueError):
                    candidate.routine_changes(self.before, after, self.contracts)

    def test_hash_only_edits_and_inconsistent_versions_are_rejected(self):
        after = self.after()
        after[candidate.PATHS[0]] = after[candidate.PATHS[0]].replace(self.new.encode(), self.old.encode())
        after[candidate.PATHS[1]] = self.before[candidate.PATHS[1]]
        with self.assertRaises(ValueError):
            candidate.routine_changes(self.before, after, self.contracts)
        after = self.after()
        after[candidate.PATHS[1]] = self.before[candidate.PATHS[1]]
        with self.assertRaisesRegex(ValueError, "disagree"):
            candidate.routine_changes(self.before, after, self.contracts)

    def test_age_assets_and_actual_digest_are_checked(self):
        changes = [{"name": "jj", "current": self.old, "target": self.new}]
        for modify in (lambda row: row.update(published_at=datetime.now(timezone.utc).isoformat()),
                       lambda row: row["assets"].pop(),
                       lambda row: row.update(prerelease=True),
                       lambda row: row["assets"][0].update(digest="sha256:" + "2" * 64)):
            row = self.metadata()[0]
            modify(row)
            with self.subTest(row=row), patch.object(candidate.stable, "github_rows", return_value=[row]), self.assertRaises(ValueError):
                candidate.release_records(changes, self.after(), self.contracts)
        row = self.metadata()[0]
        row["assets"][0].pop("digest")
        with patch.object(candidate.stable, "github_rows", return_value=[row]), patch.object(candidate, "artifact_digest", return_value=HASH) as download:
            candidate.release_records(changes, self.after(), self.contracts)
            self.assertEqual(download.call_count, 1)
            self.assertTrue(download.call_args.args[0].startswith("https://github.com/jj-vcs/jj/releases/download/"))

    def test_candidate_identity_scope_and_hash_failures(self):
        original = self.bundle()
        mutations = (
            lambda data: data.update(repository="other/repo"),
            lambda data: data.update(base="0" * 40),
            lambda data: data.update(run="124"),
            lambda data: data.update(attempt="2"),
            lambda data: data.update(schema=True),
            lambda data: data.update(extra="unknown"),
            lambda data: data.update(createdAt=(datetime.now(timezone.utc) - timedelta(days=2)).isoformat()),
            lambda data: data.update(createdAt=(datetime.now(timezone.utc) + timedelta(days=1)).isoformat()),
            lambda data: data["files"][0].update(path="../outside"),
            lambda data: data["files"][0].update(path="/absolute"),
            lambda data: data["files"].append(deepcopy(data["files"][0])),
            lambda data: data["files"][0].update(beforeSha256="0" * 64),
            lambda data: data["files"][0].update(afterSha256="0" * 64),
            lambda data: data["files"][0].update(contents="invalid base64!"),
            lambda data: data["files"][0].update(mode="100755"),
            lambda data: data["dependencies"][0]["artifacts"].pop(),
            lambda data: data["dependencies"][0]["artifacts"][0].update(url="https://other.invalid/jj"),
        )
        for index, mutate in enumerate(mutations):
            data = deepcopy(original)
            mutate(data)
            with self.subTest(index=index), self.assertRaises((ValueError, TypeError)):
                self.validate(data)
        self.assertEqual({path: (self.source / path).read_bytes() for path in candidate.PATHS}, self.before)

    def test_duplicate_json_and_size_limit(self):
        with self.assertRaisesRegex(ValueError, "duplicate"):
            candidate.decode_json(b'{"schema":1,"schema":1}')
        with self.assertRaisesRegex(ValueError, "size limit"):
            candidate.decode_json(b" " * (candidate.MAX_BUNDLE + 1))

    def test_symlink_mode_and_extra_path_are_rejected(self):
        bundle = self.bundle()
        path = self.source / candidate.PATHS[0]
        path.chmod(0o755)
        with self.assertRaises(ValueError):
            self.validate(bundle)
        path.chmod(0o644)
        outside = self.temp / "outside.toml"
        path.rename(outside)
        path.symlink_to(outside)
        with self.assertRaises(ValueError):
            self.validate(bundle)
        path.unlink()
        outside.rename(path)
        (self.source / "unexpected.txt").write_text("untracked source\n")
        with self.assertRaisesRegex(ValueError, "untracked"):
            self.validate(bundle)

    def test_manual_changes_keep_integrity_but_allow_major_review(self):
        after = self.after()
        for path, data in after.items():
            (self.source / path).write_bytes(data.replace(self.new.encode(), b"v9.0.0"))
        candidate.source_diff(self.source, self.base, routine=False)
        with self.assertRaises(ValueError):
            candidate.source_diff(self.source, self.base, routine=True)

    def test_actual_updater_preserves_inline_comments(self):
        data = self.source / candidate.PATHS[0]
        text = data.read_text().replace('version = "' + self.old + '"', 'version = "' + self.old + '"  # keep this comment')
        data.write_text(text)
        command = '. "$1"; update_toml_key_exact "$2" pinned.jj version "$3" "$4"'
        result = subprocess.run(["bash", "-c", command, "replace-test", str(ROOT / "dot_local/bin/executable_chezmoi-bump"), str(data), self.old, self.new],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('version = "' + self.new + '"  # keep this comment', data.read_text())

    def test_runner_install_verifies_digest_and_does_not_extract_paths(self):
        stream = io.BytesIO()
        with tarfile.open(fileobj=stream, mode="w:gz") as package:
            for name, body in (("../../jj", b"verified fixture binary"), ("../../unwanted", b"do not extract")):
                info = tarfile.TarInfo(name)
                info.size = len(body)
                package.addfile(info, io.BytesIO(body))
        archive = stream.getvalue()
        digest = hashlib.sha256(archive).hexdigest()
        data = self.source / candidate.PATHS[0]
        old_pin = candidate.parse_pins(self.before, self.contracts)[0]["pinned"]["jj"]
        data.write_text(data.read_text().replace(old_pin[candidate.KEYS[0]], digest))
        self.git("add", "--", candidate.PATHS[0])
        self.git("commit", "-qm", "test: runner archive")
        base = self.git("rev-parse", "HEAD").strip()
        with patch.dict(os.environ, {"RUNNER_OS": "Linux", "RUNNER_ARCH": "X64"}), patch.object(candidate.urllib.request, "build_opener") as opener:
            opener.return_value.open.return_value = io.BytesIO(archive)
            candidate.install_jj(self.source, base, self.temp / "tools")
            self.assertEqual((self.temp / "tools/jj").read_bytes(), b"verified fixture binary")
            self.assertFalse((self.temp / "unwanted").exists())
            opener.return_value.open.return_value = io.BytesIO(b"changed archive")
            with self.assertRaisesRegex(ValueError, "checksum"):
                candidate.install_jj(self.source, base, self.temp / "bad-tools")
            self.assertFalse((self.temp / "bad-tools/jj").exists())

    def test_artifact_redirects_keep_https_and_do_not_send_tokens(self):
        request = candidate.urllib.request.Request("https://github.com/owner/repo/releases/download/v1.0.1/tool")
        handler = candidate.ArtifactRedirectHandler()
        redirected = handler.redirect_request(request, None, 302, "Found", {}, "https://release-assets.githubusercontent.com/asset")
        self.assertFalse(redirected.has_header("Authorization"))
        for url in ("http://github.com/asset", "https://other.invalid/asset"):
            with self.assertRaises(ValueError):
                handler.redirect_request(request, None, 302, "Found", {}, url)


class PublisherTests(Fixture):
    def pr(self, head=None, number=1):
        return {"number": number, "state": "open", "draft": False, "user": {"login": LOGIN},
                "base": {"ref": "main", "repo": {"full_name": REPO}},
                "head": {"ref": publisher.PREFIX + RUN, "sha": head or self.base, "repo": {"full_name": REPO}}}

    def test_owner_head_and_repository_are_required(self):
        publisher.check_owner(self.pr(), REPO, "main", LOGIN, self.base)
        for mutate in (lambda pr: pr["user"].update(login="person"),
                       lambda pr: pr["head"]["repo"].update(full_name="other/repo"),
                       lambda pr: pr["base"].update(ref="other"),
                       lambda pr: pr["head"].update(ref="human-branch"),
                       lambda pr: pr.update(draft=True),
                       lambda pr: pr["head"].update(sha="2" * 40)):
            pr = self.pr()
            mutate(pr)
            with self.assertRaises(ValueError):
                publisher.check_owner(pr, REPO, "main", LOGIN, self.base)

    def test_one_open_pr_and_pagination_limit(self):
        with patch.object(publisher, "api", return_value=[self.pr(), self.pr(number=2)]), self.assertRaisesRegex(ValueError, "multiple"):
            publisher.open_routine_prs(self.source, REPO)
        with patch.object(publisher, "api", return_value=[self.pr()] * 100), self.assertRaisesRegex(ValueError, "pagination"):
            publisher.open_routine_prs(self.source, REPO)

    def test_moved_base_stops_before_publication(self):
        bundle = self.bundle()
        with patch.object(publisher, "default_state", return_value=("main", "2" * 40)), patch.object(publisher, "run") as execute:
            with self.assertRaisesRegex(ValueError, "moved"):
                publisher.publish(self.source, REPO, self.base, LOGIN, RUN, "1", bundle)
            execute.assert_not_called()

    def test_auto_merge_requires_all_checks_and_freshness(self):
        rules = [{"type": "pull_request"}, {"type": "required_status_checks", "parameters": {
            "strict_required_status_checks_policy": True,
            "required_status_checks": [{"context": name} for name in publisher.REQUIRED_CHECKS]}}]
        with patch.object(publisher, "api", return_value=rules), patch.object(publisher, "run") as merge:
            publisher.request_merge(self.source, REPO, "main", "1", self.base, True)
            self.assertIn("--match-head-commit", merge.call_args.args)
            rules[1]["parameters"]["required_status_checks"].pop()
            with self.assertRaises(ValueError):
                publisher.request_merge(self.source, REPO, "main", "1", self.base, True)
            self.assertEqual(merge.call_count, 1)

    def test_branch_refresh_uses_expected_head_and_no_force_rewrite(self):
        with patch.object(publisher, "default_state", return_value=("main", self.base)), \
             patch.object(publisher, "open_routine_prs", return_value=[self.pr()]), \
             patch.object(publisher, "check_pr_source"), patch.object(publisher.candidate, "git") as git, patch.object(publisher, "api") as api:
            git.side_effect = lambda source, *args: (self.base + "\n").encode() if args[0] == "rev-parse" else \
                (f"https://github.com/{REPO}.git\n".encode() if args[0] == "remote" else (b"2" * 40 + b"\n" if args[0] == "merge-base" else b""))
            result = publisher.publish(self.source, REPO, self.base, LOGIN, RUN, "1", existing="1", expected_head=self.base)
            self.assertEqual(result["mode"], "refresh-requested")
            self.assertEqual(api.call_args.args[2:], ("PUT", {"expected_head_sha": self.base}))
            self.assertFalse(any("push" in call.args or "reset" in call.args for call in git.call_args_list))

    @unittest.skipUnless(shutil.which("jj"), "jj is required for the real publication transaction")
    def test_real_jj_guarded_push_pr_creation_and_failed_pr_recovery(self):
        bundle = self.bundle()
        real_jj = shutil.which("jj")
        trace = self.temp / "trace"
        self.tool("jj", '#!/bin/sh\nif [ "$1" = git ] && [ "$2" = push ]; then printf "push\\n" >> "$PUBLISH_TRACE"; exit 0; fi\nexec ' + shlex.quote(real_jj) + ' "$@"\n')
        self.tool("gitleaks", '#!/bin/sh\nprintf "scan\\n" >> "$PUBLISH_TRACE"\n')
        os.environ["PUBLISH_TRACE"] = str(trace)
        created = []
        saved = {}
        fail_pr = [True]

        def api(source, path, method="GET", body=None, missing=False):
            if path == f"repos/{REPO}":
                return {"default_branch": "main"}
            if path.endswith("git/ref/heads/main"):
                return {"object": {"sha": self.base}}
            if "/pulls?" in path:
                return []
            if path == "users/" + LOGIN:
                return {"login": LOGIN, "type": "Bot", "id": 1234}
            if path.endswith("git/ref/heads/" + publisher.PREFIX + RUN):
                return {"object": {"sha": saved["head"]}} if "head" in saved else None
            if "/commits/" in path:
                email = f"1234+{LOGIN}@users.noreply.github.com"
                return {"author": {"login": LOGIN}, "committer": {"login": LOGIN},
                        "commit": {"author": {"email": email}, "committer": {"email": email}}, "parents": [{"sha": self.base}]}
            if path.endswith("/pulls") and method == "POST":
                saved["head"] = candidate.git(source, "rev-parse", "refs/heads/" + publisher.PREFIX + RUN).decode().strip() if "head" not in saved else saved["head"]
                if fail_pr[0]:
                    fail_pr[0] = False
                    raise ValueError("injected PR creation failure")
                created.append(body)
                return self.pr(saved["head"])
            raise AssertionError((path, method))

        with patch.object(publisher, "api", side_effect=api):
            with self.assertRaisesRegex(ValueError, "injected"):
                publisher.publish(self.source, REPO, self.base, LOGIN, RUN, "1", bundle)
            self.assertEqual(trace.read_text().splitlines(), ["scan", "scan", "push"])
            self.assertEqual(self.git("show", "-s", "--format=%ae%x00%ce", saved["head"]).strip().split("\0"),
                             [f"1234+{LOGIN}@users.noreply.github.com"] * 2)
            # A workflow retry has a fresh base checkout and all the old branch objects.
            retry = self.temp / "retry"
            result = subprocess.run(["git", "clone", "--no-hardlinks", "--quiet", "--branch", "main", str(self.source), str(retry)], capture_output=True, env=self.env)
            self.assertEqual(result.returncode, 0, result.stderr)
            candidate.git(retry, "remote", "set-url", "origin", f"https://github.com/{REPO}.git")
            actual_git = publisher.candidate.git
            def fetch_is_local(source, *args):
                return b"" if args[0] == "fetch" else actual_git(source, *args)
            with patch.object(publisher.candidate, "git", side_effect=fetch_is_local):
                result = publisher.publish(retry, REPO, self.base, LOGIN, RUN, "1", bundle)
            self.assertEqual(result["mode"], "created")
            self.assertEqual(len(created), 1)
            self.assertIn("\n", created[0]["body"])
            self.assertEqual(trace.read_text().count("push"), 1)

    def test_workflow_credential_boundaries_and_trusted_policy(self):
        workflow = (ROOT / ".github/workflows/safe-daily-updates.yml").read_text()
        prepare, publish = workflow.split("\n  publish:", 1)
        self.assertNotIn("APP_PRIVATE_KEY", prepare)
        self.assertNotRegex(workflow, r"(?m)^\s+contents:\s+write$")
        self.assertIn("permission-contents: write", publish)
        self.assertIn("permission-pull-requests: write", publish)
        self.assertLess(publish.index("Revalidate with read permissions"), publish.index("Mint a repository-scoped"))
        self.assertIn("default: false", prepare)
        self.assertNotIn("schedule:", workflow)
        policy = (ROOT / ".github/workflows/maintenance-policy.yml").read_text()
        self.assertIn("pull_request_target:", policy)
        self.assertIn("ref: ${{ github.sha }}", policy)
        self.assertIn("--head \"$PR_HEAD\"", policy)
        self.assertIn("statuses: write", policy)
        self.assertNotIn("contents: write", policy)
        self.assertNotIn("secrets.", policy)
        self.assertNotIn("npm", policy)
        self.assertNotIn("checkout --", policy)
        # bash -e continues after a failed test before &&, so a guard must use if and exit.
        for text in (workflow, policy):
            self.assertNotRegex(text, r"(?m)^\s*\[[^\n]*\]\s*&&\s*\[[^\n]*\]\s*$")


class ReviewedUpdateTests(unittest.TestCase):
    def test_reviewed_apply_gates_and_receipt(self):
        with temporary_directory() as directory:
            root = Path(directory)
            source, tools = root / "source", root / "bin"
            source.mkdir()
            tools.mkdir()
            (source / ".chezmoidata.toml").write_text("[git]\n")
            lib = root / ".local/lib"
            lib.mkdir(parents=True)
            shutil.copy2(ROOT / "dot_local/private_lib/chezmoi-update-helpers.sh", lib / "chezmoi-update-helpers.sh")
            shutil.copytree(ROOT / "dot_local/private_lib/chezmoi", lib / "chezmoi")
            log = root / "calls"
            scripts = {
                "jj": '''#!/bin/sh
printf 'jj %s\n' "$*" >> "$REVIEW_LOG"
case " $* " in
  *' root '*) printf '%s\n' "$REVIEW_SOURCE" ;;
  *' diff -r @ --summary '*) [ "$REVIEW_DIRTY" != 1 ] || echo 'M local' ;;
  *' conflicts() & @ '*) [ "$REVIEW_CONFLICT" != 1 ] || echo conflict ;;
  *' diff --from trunk() --to @ '*) [ "$REVIEW_LOCAL_STACK" != 1 ] || echo 'M unmerged' ;;
  *' log -r trunk() '*) printf '1111111111111111111111111111111111111111' ;;
esac
exit 0
''',
                "jj-sync-trunk": '#!/bin/sh\necho sync >> "$REVIEW_LOG"\nexit "${REVIEW_SYNC_FAIL:-0}"\n',
                "chezmoi": '''#!/bin/sh
case "$1" in
  data) echo '{"profile":"standard"}' ;;
  *) printf 'apply %s force=%s\n' "$*" "${CHEZMOI_FORCE_UPDATE:-unset}" >> "$REVIEW_LOG"; exit "${REVIEW_APPLY_FAIL:-0}" ;;
esac
''',
                "chezmoi-health-check": '#!/bin/sh\necho health >> "$REVIEW_LOG"\nexit "${REVIEW_HEALTH_FAIL:-0}"\n',
            }
            for name, body in scripts.items():
                path = tools / name
                path.write_text(body)
                path.chmod(0o755)
            env = {**os.environ, "HOME": str(root), "PATH": f"{tools}{os.pathsep}{os.environ['PATH']}",
                   "CHEZMOI_SOURCE_DIR": str(source), "CHEZMOI_DIR": str(source), "XDG_STATE_HOME": str(root / "state"),
                   "REVIEW_LOG": str(log), "REVIEW_SOURCE": str(source), "REVIEW_DIRTY": "0", "REVIEW_CONFLICT": "0", "REVIEW_LOCAL_STACK": "0"}
            command = ["bash", str(ROOT / "dot_local/bin/executable_czu"), "--reviewed"]
            result = subprocess.run(command, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            receipt = root / "state/chezmoi-maintenance/last-reviewed-update.json"
            prior = receipt.read_bytes()
            self.assertEqual(json.loads(prior)["revision"], "1" * 40)
            self.assertEqual(receipt.stat().st_mode & 0o777, 0o600)
            self.assertIn("force=unset", log.read_text())
            for changes, forbidden in (({"REVIEW_DIRTY": "1"}, "sync"), ({"REVIEW_SYNC_FAIL": "1"}, "apply"),
                                       ({"REVIEW_CONFLICT": "1"}, "apply"), ({"REVIEW_LOCAL_STACK": "1"}, "apply"),
                                       ({"REVIEW_APPLY_FAIL": "1"}, "health"), ({"REVIEW_HEALTH_FAIL": "1"}, None)):
                log.write_text("")
                result = subprocess.run(command, env={**env, **changes}, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                if forbidden:
                    self.assertNotIn(forbidden, log.read_text())
                self.assertEqual(receipt.read_bytes(), prior)
            log.write_text("")
            result = subprocess.run([*command, "--dry-run"], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(log.read_text(), "")


if __name__ == "__main__":
    program = unittest.main(exit=False)
    if not program.result.wasSuccessful():
        sys.exit(1)
    sys.exit(77 if program.result.skipped else 0)
