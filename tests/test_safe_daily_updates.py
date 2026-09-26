#!/usr/bin/env python3
"""Offline checks for the staged daily update policy."""

import importlib.util
import io
from contextlib import redirect_stderr
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import shutil
import time
import sys
from unittest.mock import patch
from datetime import datetime, timedelta, timezone

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("stable", ROOT / "dot_local/private_lib/chezmoi/stable-release-eligibility.py")
stable = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(stable)
NOW = datetime(2026, 9, 26, 12, tzinfo=timezone.utc)


def release(tag, age, **fields):
    return {"tag_name": tag, "published_at": (NOW - timedelta(days=age)).isoformat(), **fields}


class Selection(unittest.TestCase):
    def test_age_sort_and_risk(self):
        rows = [release("v3.0.0", 0.3), release("v2.4.0", 7), release("v2.3.0", 40)]
        self.assertEqual(stable.select(rows, "v2.2.0", NOW), ("eligible", "v2.4.0"))
        self.assertEqual(stable.select(rows, "v2.4.0", NOW)[0], "too_new")
        self.assertEqual(stable.risk("0.12.0", "0.13.0"), "major_review")
        self.assertEqual(stable.risk("0.12.1", "0.12.2"), "eligible")
        self.assertEqual(stable.risk("2.4.0", "2.3.0"), "current")

    def test_invalid_metadata_fails(self):
        for stamp in (None, "2026-09-19T12:00:00", "2026-09-19T12:00:00BAD", "2026-09-27T12:00:00Z", "2026-02-30T00:00:00Z", "2026-01-01T00:00:00+01:99"):
            with self.subTest(stamp=stamp), self.assertRaises(ValueError):
                stable.select([{"tag_name": "v2.0.0", "published_at": stamp}], "v1.0.0", NOW)
        self.assertEqual(stable.select([release("v2.0.0-rc1", 20), release("main", 20), release("v1.1.0", 20, draft=True)], "v1.0.0", NOW)[0], "current")
        with self.assertRaises(ValueError):
            stable.select([], "v1.0.0", NOW)

    def test_assets_and_npm(self):
        rows = [release("v1.3.0", 20, assets=[{"name": "linux"}]), release("v1.2.0", 20, assets=[{"name": "linux"}, {"name": "mac"}])]
        self.assertEqual(stable.select(rows, "v1.0.0", NOW, required_assets=("linux", "mac")), ("eligible", "v1.2.0"))
        complete = [{"name": name} for name in stable.release_assets("jj", "v1.2.0")]
        rows = [release("v1.3.0", 20, assets=complete[:-1]), release("v1.2.0", 20, assets=complete)]
        self.assertEqual(stable.select(rows, "v1.0.0", NOW, dependency="jj"), ("eligible", "v1.2.0"))
        self.assertEqual(stable.select(rows[:1], "v1.0.0", NOW, dependency="jj")[0], "unsupported")
        with self.assertRaises(ValueError):
            stable.select([release("v1.2.0", 20, assets={})], "v1.0.0", NOW, dependency="jj")
        with patch.object(stable, "fetch_json", return_value={"versions": {"1.2.0": {}}, "time": {"1.2.0": "2026-09-19T12:00:00Z"}}):
            self.assertEqual(stable.npm_rows("example")[0]["tag_name"], "1.2.0")
        with patch.dict(os.environ, {"CHEZMOI_NPM_REGISTRY": "https://private.invalid"}):
            with self.assertRaises(ValueError):
                stable.npm_rows("example")

    def test_pagination_and_failure(self):
        batches = [[release("v3.0.0", 0.3)] * 100, [release("v2.4.0", 7)] * 100, [release("v2.3.0", 40)]]
        with patch.object(stable, "fetch_json", side_effect=batches):
            rows = stable.github_rows("owner/repo")
        self.assertEqual(stable.select(rows, "v2.0.0", NOW), ("eligible", "v2.4.0"))
        with patch.object(stable, "fetch_json", side_effect=batches[:2]):
            with self.assertRaises(ValueError):
                stable.github_rows("owner/repo", cap=2)
        with patch.object(stable, "fetch_json", side_effect=OSError("rate limit")):
            with self.assertRaises(OSError):
                stable.github_rows("owner/repo")

    def test_timer_guard_repeats(self):
        script = ROOT / ".chezmoiscripts/run_after_38-setup-pi-maintenance-agent.sh.tmpl"
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            helper = home / ".local/lib/chezmoi-helpers.sh"
            helper.parent.mkdir(parents=True)
            helper.write_text('eecho() { echo "$*" >&2; }\n')
            (home / ".config/dotfiles").mkdir(parents=True)
            (home / ".config/dotfiles/pi-maintenance-agent.enabled").touch()
            stub = home / "systemctl"
            log = home / "calls"
            stub.write_text(f'#!{sys.executable}\n' + '''
import os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ["CALL_LOG"], "a") as stream:
    stream.write(" ".join(args) + "\\n")
if "show" in args:
    print(os.environ.get("TEST_LOAD_STATE", "loaded"))
elif "disable" in args and os.environ.get("TEST_DISABLE_FAIL"):
    sys.exit(1)
elif "stop" in args and os.environ.get("TEST_STOP_FAIL"):
    sys.exit(1)
elif "is-active" in args:
    print(os.environ.get("TEST_ACTIVE_STATE", "inactive"))
    sys.exit(3)
elif "is-enabled" in args:
    print("disabled")
    sys.exit(1)
''')
            stub.chmod(0o755)
            env = {**os.environ, "HOME": str(home), "PATH": f"{home}:{os.environ['PATH']}", "CALL_LOG": str(log)}
            for _ in range(2):
                subprocess.run(["bash", str(script)], env=env, check=True)
            self.assertEqual(log.read_text().count("--user disable --now pi-maintenance-agent.timer"), 2)
            self.assertNotIn("--user enable ", log.read_text())
            for changes, success in (({"TEST_LOAD_STATE": "not-found"}, True),
                                     ({"TEST_DISABLE_FAIL": "1"}, False),
                                     ({"TEST_STOP_FAIL": "1"}, False),
                                     ({"TEST_ACTIVE_STATE": "active"}, False)):
                with self.subTest(changes=changes):
                    result = subprocess.run(["bash", str(script)], env={**env, **changes}, capture_output=True)
                    self.assertEqual(result.returncode == 0, success)
            calls = log.read_text()
            no_systemd = {**env, "PATH": str(home / "missing-bin")}
            subprocess.run([shutil.which("bash"), str(script)], env=no_systemd, check=True)
            self.assertEqual(log.read_text(), calls)

    @unittest.skipUnless(shutil.which("node"), "Node is needed to inspect npm locks")
    def test_npm_transitive_lock_gate(self):
        helper = ROOT / "dot_local/private_lib/chezmoi/npm.sh"
        with tempfile.TemporaryDirectory() as directory:
            lock = Path(directory) / "package-lock.json"
            lock.write_text(json.dumps({"packages": {"": {}, "node_modules/direct": {"version": "1.0.0"}, "node_modules/direct/node_modules/transitive": {"version": "2.0.0"}}}))
            command = f'source "{helper}"; NPM_CMD="$(command -v npm)"; npm_lockfile_package_specs "{lock}"'
            manual = {**os.environ, "CHEZMOI_AUTOMATIC_UPDATES": "0"}
            result = subprocess.run(["bash", "-c", command], env=manual, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("direct\t1.0.0", result.stdout)
            self.assertIn("transitive\t2.0.0", result.stdout)
            lock.write_text(json.dumps({"packages": {"": {}, "node_modules/direct": {"version": "1.0.0"}, "node_modules/transitive": {}}}))
            result = subprocess.run(["bash", "-c", command], env=manual, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)

            for packages in ([{"version": "1.0.0"}], {"node_modules/direct": {"version": "1.0.0", "resolved": "git+https://example.invalid/direct"}},
                             {"node_modules/direct": {"version": "1.0.0", "resolved": "https://private.invalid/direct.tgz"}},
                             {"node_modules/direct": {"version": "1.0.0"}}):
                lock.write_text(json.dumps({"lockfileVersion": 3, "packages": packages}))
                automatic = {**os.environ, "CHEZMOI_AUTOMATIC_UPDATES": "1", "CHEZMOI_NPM_MIN_VERSION_AGE_DAYS": "7"}
                result = subprocess.run(["bash", "-c", command], env=automatic, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)

            package = {"version": "1.0.0", "resolved": "https://registry.npmjs.org/direct/-/direct-1.0.0.tgz",
                       "integrity": "sha512-" + "A" * 86 + "=="}
            lock.write_text(json.dumps({"lockfileVersion": 3, "packages": {"node_modules/direct": package}}))
            result = subprocess.run(["bash", "-c", command], env=automatic, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            package["resolved"] = "https://registry.npmjs.org/other/-/other-1.0.0.tgz"
            lock.write_text(json.dumps({"lockfileVersion": 3, "packages": {"node_modules/direct": package}}))
            result = subprocess.run(["bash", "-c", command], env=automatic, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)

    @unittest.skipUnless(shutil.which("node"), "Node is needed to inspect npm dates")
    def test_npm_exact_publication_time(self):
        helper = ROOT / "dot_local/private_lib/chezmoi/npm.sh"
        command = f'source "{helper}"; npm_publish_epoch_from_json "$(command -v node)" 1.0.0'
        env = {**os.environ, "CHEZMOI_AUTOMATIC_UPDATES": "1"}
        for timestamp, valid in (("2026-02-28T00:00:00Z", True), ("2026-02-28T00:00:00.500Z", True),
                                 ("2024-02-29T03:30:00+03:30", True),
                                 ("2026-02-30T00:00:00Z", False), ("2026-02-28T24:00:00Z", False),
                                 ("2026-02-28T00:00:00", False), ("9999-01-01T00:00:00Z", False), (None, False)):
            with self.subTest(timestamp=timestamp):
                result = subprocess.run(["bash", "-c", command], input=json.dumps({"1.0.0": timestamp}),
                                        env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, valid, result.stderr)
                if timestamp == "2026-02-28T00:00:00.500Z":
                    self.assertEqual(int(result.stdout), int(datetime(2026, 2, 28, tzinfo=timezone.utc).timestamp()) + 1)

    def test_npm_cache_ttl_boundary(self):
        helper = ROOT / "dot_local/private_lib/chezmoi/npm.sh"
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory) / "cache.json"
            cache.write_text("{}")
            command = f'source "{helper}"; npm_publish_metadata_cache_is_fresh "{cache}"'
            now = int(time.time())
            os.utime(cache, (now - 86399, now - 86399))
            self.assertEqual(subprocess.run(["bash", "-c", command]).returncode, 0)
            os.utime(cache, (now - 86401, now - 86401))
            self.assertNotEqual(subprocess.run(["bash", "-c", command]).returncode, 0)
            os.utime(cache, (now + 60, now + 60))
            self.assertNotEqual(subprocess.run(["bash", "-c", command]).returncode, 0)

    def test_automatic_flags_fail_closed(self):
        bump = ROOT / "dot_local/bin/executable_chezmoi-bump"
        for args, overrides in (([], {"CHEZMOI_NPM_MIN_VERSION_AGE_DAYS": "0"}),
                                ([], {"npm_config_registry": "https://private.invalid"}),
                                (["--skip-sha"], {}), (["--no-strict"], {}), (["--no-rollback"], {}),
                                (["fzf"], {}), ([], {"CHEZMOI_RELEASE_FIXTURE_DIR": "/missing"})):
            with self.subTest(args=args, overrides=overrides):
                env = {**os.environ, "CHEZMOI_DIR": str(ROOT), "CHEZMOI_NPM_MIN_VERSION_AGE_DAYS": "7", **overrides}
                result = subprocess.run(["bash", str(bump), "--automatic", "--all", "--check", *args], env=env, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Automatic mode requires", result.stderr)

    def test_shared_npm_policy_cannot_be_bypassed(self):
        helper = ROOT / "dot_local/private_lib/chezmoi/npm.sh"
        command = (f'source "{helper}"; eecho() {{ echo "$*" >&2; }}; '
                   'npm_query_publish_epoch() { echo QUERY >&2; echo 1; }; '
                   'npm_require_minimum_version_age example 1.0.0')
        for overrides in ({"CHEZMOI_NPM_MIN_VERSION_AGE_DAYS": "0"},
                          {"CHEZMOI_NPM_REGISTRY": "https://private.invalid"},
                          {"npm_config_registry": "https://private.invalid"}):
            with self.subTest(overrides=overrides):
                env = {**os.environ, "CHEZMOI_AUTOMATIC_UPDATES": "1", "CHEZMOI_NPM_MIN_VERSION_AGE_DAYS": "7", **overrides}
                result = subprocess.run(["bash", "-c", command], env=env, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("QUERY", result.stderr)

    def test_github_token_is_scoped_and_not_redirected(self):
        with patch.dict(os.environ, {"GITHUB_TOKEN": "test-only-value"}), patch.object(stable.urllib.request, "build_opener") as opener:
            request = opener.return_value.open
            for url, authenticated in (("https://api.github.com/repos/owner/repo/releases", True),
                                       ("https://registry.npmjs.org/example", False)):
                request.return_value = io.BytesIO(b"{}")
                stable.fetch_json(url)
                sent = request.call_args.args[0]
                self.assertEqual(sent.has_header("Authorization"), authenticated)
                redirected = stable.urllib.request.HTTPRedirectHandler().redirect_request(
                    sent, None, 302, "Found", {}, "https://example.invalid/redirect")
                self.assertFalse(redirected.has_header("Authorization"))
                handler = stable.MetadataRedirectHandler()
                same_origin = handler.redirect_request(sent, None, 302, "Found", {}, url + "/moved")
                self.assertFalse(same_origin.has_header("Authorization"))
                for newurl in ("https://example.invalid/redirect", url.replace("https:", "http:")):
                    with self.assertRaises(ValueError):
                        handler.redirect_request(sent, None, 302, "Found", {}, newurl)

    def test_npm_requires_current_version_metadata(self):
        metadata = {"versions": {"1.0.0": {}}, "time": {"1.0.0": "2026-01-01T00:00:00Z", "2.0.0": "2026-01-01T00:00:00Z"}}
        with patch.object(stable, "fetch_json", return_value=metadata):
            self.assertEqual([row["tag_name"] for row in stable.npm_rows("example")], ["1.0.0"])
        for metadata in ({"time": {}}, {"versions": {"1.0.0": {}}, "time": {}}):
            with patch.object(stable, "fetch_json", return_value=metadata), self.assertRaises(ValueError):
                stable.npm_rows("example")

    def test_automatic_resolver_rejects_test_overrides(self):
        for args, overrides in ((["--now", NOW.isoformat()], {}),
                                ([], {"CHEZMOI_RELEASE_FIXTURE_DIR": "/missing"})):
            with patch.dict(os.environ, {"CHEZMOI_AUTOMATIC_UPDATES": "1", **overrides}), \
                 patch.object(sys, "argv", ["resolver", "owner/repo", "1.0.0", *args]), \
                 patch.object(stable, "github_rows", side_effect=AssertionError("network query")):
                with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as stopped:
                    stable.main()
                self.assertNotEqual(stopped.exception.code, 0)

    def test_automatic_report_never_starts_a_transaction(self):
        bump = ROOT / "dot_local/bin/executable_chezmoi-bump"
        command = (f'source "{bump}"; ALL_DEPS=("fzf|junegunn/fzf|raw|none|0"); '
                   'resolve_automatic_candidate() { printf "eligible\\tv0.74.5\\n"; }; '
                   'run_all_dependency_transactions() { echo UNEXPECTED >&2; return 1; }; '
                   'main --automatic --all --check')
        env = {**os.environ, "CHEZMOI_DIR": str(ROOT), "CHEZMOI_NPM_MIN_VERSION_AGE_DAYS": "7"}
        result = subprocess.run(["bash", "-c", command], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("fzf: eligible", result.stdout)
        self.assertNotIn("UNEXPECTED", result.stderr)

    def test_automatic_transaction_retains_selected_candidates(self):
        bump = ROOT / "dot_local/bin/executable_chezmoi-bump"
        command = f'source "{bump}"; ' + '''
ALL_DEPS=("fzf|junegunn/fzf|raw|none|0" "pi|npm:example|raw|none|0" "uv|astral-sh/uv|raw|sidecar|4")
get_current_version() { echo 1.0.0; }
resolve_automatic_candidate() {
    case "$1" in
        uv) printf 'major_review\\t2.0.0\\n' ;;
        *) printf 'eligible\\t1.0.1\\n' ;;
    esac
}
run_all_dependency_transactions() {
    [ "$*" = 'fzf pi' ] && [ "$MANIFEST_MULTI" = true ] || return 1
    [ "$(get_latest_version fzf junegunn/fzf raw)" = '1.0.1' ] || return 1
    resolve_automatic_candidate() { printf 'eligible\\t1.0.2\\n'; }
    if get_latest_version fzf junegunn/fzf raw; then return 1; fi
    echo 'Candidate change blocked; outer transaction retained.'
}
main --automatic --all --manifest-out /unused-test-manifest
'''
        env = {**os.environ, "CHEZMOI_DIR": str(ROOT), "CHEZMOI_NPM_MIN_VERSION_AGE_DAYS": "7"}
        result = subprocess.run(["bash", "-c", command], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Candidate change blocked; outer transaction retained.", result.stdout)

    def test_checker_and_resolver_agree_for_fzf(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            (fixture / "page-1.json").write_text(json.dumps([{"tag_name": "v0.74.5", "published_at": "2024-01-01T00:00:00Z"}]))
            source = fixture / "source"
            helper = source / "dot_local/private_lib/chezmoi/stable-release-eligibility.py"
            helper.parent.mkdir(parents=True)
            shutil.copyfile(SPEC.origin, helper)
            pins = source / ".chezmoiexternal.toml.tmpl"
            pins.write_text('''[".local/share/fzf"]
clone.args = ["--branch", "v0.74.4"]
[".oh-my-zsh/custom/plugins/zsh-syntax-highlighting"]
url = "https://github.com/zsh-users/zsh-syntax-highlighting/archive/refs/tags/0.8.0.tar.gz"
refreshPeriod = "168h"
[".oh-my-zsh/custom/plugins/zsh-autosuggestions"]
url = "https://github.com/zsh-users/zsh-autosuggestions/archive/refs/tags/v0.7.1.tar.gz"
refreshPeriod = "168h"
''')
            env = {**os.environ, "HOME": directory, "CHEZMOI_DIR": str(source), "CHEZMOI_RELEASE_FIXTURE_DIR": directory,
                   "CHEZMOI_AUTOMATIC_UPDATES": "0", "XDG_CACHE_HOME": str(fixture / "cache")}
            checker = subprocess.run(["bash", str(ROOT / "dot_local/bin/executable_chezmoi-check-versions"), "--force"], env=env, capture_output=True, text=True)
            self.assertEqual(checker.returncode, 0, checker.stderr)
            self.assertIn("| fzf | 0.74.4 | v0.74.5 | eligible |", checker.stdout)
            resolver = subprocess.run(["python3", str(ROOT / "dot_local/private_lib/chezmoi/stable-release-eligibility.py"), "junegunn/fzf", "0.74.4", "--now", NOW.isoformat()], env=env, capture_output=True, text=True)
            self.assertEqual(resolver.returncode, 0, resolver.stderr)
            self.assertEqual(resolver.stdout.strip(), "eligible\tv0.74.5")
            pins.write_text(pins.read_text().replace('v0.74.4', 'v0.74.5'))
            updated = subprocess.run(["bash", str(ROOT / "dot_local/bin/executable_chezmoi-check-versions")], env=env, capture_output=True, text=True)
            self.assertEqual(updated.returncode, 0, updated.stderr)
            self.assertIn("| fzf | 0.74.5 |", updated.stdout)
            self.assertNotIn("eligible |", updated.stdout)
            other = fixture / "other-source"
            shutil.copytree(source, other)
            (fixture / "page-1.json").write_text(json.dumps([{"tag_name": "v0.74.6", "published_at": "2024-01-01T00:00:00Z"}]))
            isolated = subprocess.run(["bash", str(ROOT / "dot_local/bin/executable_chezmoi-check-versions")],
                                      env={**env, "CHEZMOI_DIR": str(other)}, capture_output=True, text=True)
            self.assertEqual(isolated.returncode, 0, isolated.stderr)
            self.assertIn("| fzf | 0.74.5 | v0.74.6 | eligible |", isolated.stdout)

    def test_workflow_is_report_only(self):
        workflow = (ROOT / ".github/workflows/safe-daily-updates.yml").read_text()
        self.assertIn("workflow_dispatch:", workflow)
        self.assertNotIn("schedule:", workflow)
        self.assertNotIn("contents: write", workflow)
        self.assertNotIn("pull-requests: write", workflow)
        self.assertNotIn("sudo", workflow)
        self.assertIn("if: github.ref == format('refs/heads/{0}', github.event.repository.default_branch)", workflow)
        self.assertIn("ref: ${{ github.sha }}", workflow)
        self.assertIn("--automatic --all --check", workflow)
        self.assertNotIn("--dry-run", workflow)


if __name__ == "__main__":
    program = unittest.main(exit=False)
    if not program.result.wasSuccessful():
        sys.exit(1)
    sys.exit(77 if program.result.skipped else 0)
