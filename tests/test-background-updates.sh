#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=tests/lib/temp.sh
. "$REPO_ROOT/tests/lib/temp.sh"
new_test_temp_dir TEST_DIR
trap 'remove_test_temp_dir "$TEST_DIR"' EXIT

python3 - "$REPO_ROOT" "$TEST_DIR" <<'PY'
import json
import os
import stat
import subprocess
import sys
import unittest
from pathlib import Path

repo, fixture_root = map(Path, sys.argv[1:])
checker = repo / "dot_local/bin/executable_dotfiles-update-check"
sys.argv = [sys.argv[0]]

# Every reachable command is a stub. No host package, source or history command
# can run, even if the checker accidentally requests one.
stub = r'''#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
name = Path(sys.argv[0]).name
args = sys.argv[1:]
env = os.environ
with open(env["STUB_LOG"], "a") as output:
    json.dump({"command": name, "args": args, "source": env.get("CHEZMOI_DIR"),
               "prompt": env.get("GIT_TERMINAL_PROMPT"),
               "optionalLocks": env.get("GIT_OPTIONAL_LOCKS"),
               "ssh": env.get("GIT_SSH_COMMAND"),
               "checkDb": env.get("CHECKUPDATES_DB")}, output)
    output.write("\n")
if env.get("STUB_SLEEP_COMMAND") == name:
    time.sleep(5)
if name == "jj":
    assert args[:3] == ["--ignore-working-copy", "-R", env["STUB_SOURCE"]], args
    if args[3:] == ["root"]:
        print(env.get("STUB_JJ_ROOT", env["STUB_SOURCE"]))
    else:
        assert args[3:] == ["log", "-r", "trunk()", "--no-graph", "--template", "commit_id"], args
        print("a" * 40)
elif name == "chezmoi":
    assert args == ["source-path"], args
    print(env["STUB_SOURCE"])
elif name == "git":
    fallback = args[:2] == ["-c", "credential.helper="]
    if fallback:
        args = args[2:]
    assert args[:2] == ["-C", env["STUB_SOURCE"]], args
    if args[2] == "ls-remote":
        remote = "https://github.com/example/dotfiles.git" if fallback else "origin"
        assert args[3:] == ["--symref", "--exit-code", remote, "HEAD"], args
        if env.get("STUB_HTTPS_FAILURE" if fallback else "STUB_REMOTE_FAILURE"):
            print("Public HTTPS connection failed" if fallback else "SSH connection failed", file=sys.stderr)
            sys.exit(1)
        print("ref: refs/heads/master\tHEAD")
        print(env.get("STUB_REMOTE_HEAD", "a" * 40) + "\tHEAD")
    elif args[2:] == ["remote", "get-url", "origin"]:
        print(env.get("STUB_REMOTE_URL", "git@github.com:example/dotfiles.git"))
    elif args[2:] == ["rev-parse", "--verify", "HEAD"]:
        print("a" * 40)
    elif args[2:] == ["status", "--porcelain", "--untracked-files=normal"]:
        print(env.get("STUB_DIRTY_SOURCE", ""))
    elif args[2:] == ["show", "a" * 40 + ":dot_local/private_lib/chezmoi/stable-release-eligibility.py"]:
        sys.stdout.write("print('verified')\n")
    else:
        raise AssertionError("Unexpected Git command: " + repr(args))
elif name == "checkupdates":
    assert args == ["--nocolor"], args
    print(env.get("STUB_ARCH_OUTPUT", ""))
    sys.exit(int(env.get("STUB_ARCH_CODE", "2")))
elif name == "yay":
    assert args == ["-Qua"], args
    print(env.get("STUB_AUR_OUTPUT", ""))
    sys.exit(int(env.get("STUB_AUR_CODE", "0")))
elif name == "chezmoi-bump":
    if args == ["--inventory"]:
        print(json.dumps([{"name": "uv"}, {"name": "codex"}]))
        sys.exit(0)
    assert args[:4] == ["--automatic", "--all", "--check", "--report-out"], args
    if env.get("STUB_PIN_FAILURE"):
        print("Release metadata is unavailable", file=sys.stderr)
        sys.exit(1)
    target = Path(args[4])
    if env.get("STUB_PIN_INVALID"):
        target.write_text("invalid JSON")
    else:
        rows = [{"name": "uv", "state": env.get("STUB_PIN_STATE", "current")},
                {"name": "codex", "state": "manual"}]
        if env.get("STUB_PIN_PARTIAL"):
            rows = rows[:1]
        if env.get("STUB_PIN_DUPLICATE"):
            rows = [rows[0], rows[0]]
        target.write_text(json.dumps({"schema": 1, "dependencies": rows}))
    print("Supported pin metadata scan finished")
elif name == "notify-send":
    sys.exit(int(env.get("STUB_NOTIFY_CODE", "0")))
else:
    raise AssertionError("Forbidden command: " + name)
'''

launcher = '''
import importlib.machinery, importlib.util, sys
path, bound = sys.argv[1:3]
loader = importlib.machinery.SourceFileLoader("update_checker", path)
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)
for name in ("COMMAND_TIMEOUT", "PIN_TIMEOUT", "LOCAL_TIMEOUT", "REMOTE_TIMEOUT", "AUR_TIMEOUT"):
    setattr(module, name, float(bound))
sys.argv = ["dotfiles-update-check", *sys.argv[3:]]
raise SystemExit(module.main())
'''


class BackgroundUpdates(unittest.TestCase):
    def setUp(self):
        self.case = fixture_root / self.id().rsplit(".", 1)[-1]
        self.case.mkdir()
        self.source = self.case / "source"
        self.source.mkdir()
        (self.source / ".chezmoidata.toml").write_text("[pinned]\n")
        self.helper = self.source / "dot_local/private_lib/chezmoi/stable-release-eligibility.py"
        self.helper.parent.mkdir(parents=True)
        self.helper.write_text("print('verified')\n")
        self.bin = self.case / "bin"
        self.bin.mkdir()
        (self.bin / "python3").symlink_to(sys.executable)
        for command in ("git", "jj", "chezmoi", "checkupdates", "yay", "chezmoi-bump", "notify-send",
                        "sudo", "pacman", "omarchy", "mise", "czu", "czuf", "jj-sync-trunk"):
            path = self.bin / command
            path.write_text(stub)
            path.chmod(0o700)
        self.state_root = self.case / "state"
        self.state = self.state_root / "chezmoi-maintenance"
        self.report = self.state / "last-update-check.txt"
        self.log = self.case / "commands.jsonl"
        self.env = dict(os.environ)
        for name in ("CHEZMOI_SOURCE_DIR", "CHEZMOI_DIR", "CHEZMOI_JJ_REMOTE", "JJ_REMOTE"):
            self.env.pop(name, None)
        self.env.update(PATH=str(self.bin), XDG_STATE_HOME=str(self.state_root),
                        CHEZMOI_SOURCE_DIR=str(self.source), STUB_SOURCE=str(self.source),
                        STUB_LOG=str(self.log))

    def run_check(self, args=(), timeout=2):
        result = subprocess.run([sys.executable, "-c", launcher, str(checker), str(timeout), *args],
                                cwd=self.case, env=self.env, capture_output=True, text=True, timeout=12)
        self.assertEqual((self.source / ".chezmoidata.toml").read_text(), "[pinned]\n")
        return result

    def events(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def notifications(self):
        return [event for event in self.events() if event["command"] == "notify-send"]

    def test_no_updates_is_quiet_and_read_only(self):
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        text = self.report.read_text()
        self.assertIn("Source parent matches remote HEAD", text)
        self.assertIn("No official Arch package updates", text)
        self.assertIn("Manual-only dependencies were not checked: codex", text)
        self.assertFalse(self.notifications())
        self.assertEqual(stat.S_IMODE(self.state.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(self.report.stat().st_mode), 0o600)
        for event in self.events():
            self.assertEqual(event["prompt"], "0")
            self.assertEqual(event["optionalLocks"], "0")
            self.assertIn("BatchMode=yes", event["ssh"])
            self.assertTrue(event["checkDb"].startswith(str(self.state) + "/"))
            self.assertIn(event["command"], {"git", "jj", "checkupdates", "yay", "chezmoi-bump"})
        self.assertFalse(list(self.state.glob(".pin-check-*")))

    def test_updates_notify_with_install_command_and_report(self):
        self.env.update(STUB_REMOTE_HEAD="b" * 40, STUB_ARCH_CODE="0",
                        STUB_ARCH_OUTPUT="package 1 -> 2", STUB_AUR_OUTPUT="aur-package 1 -> 2",
                        STUB_PIN_STATE="eligible")
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        text = self.report.read_text()
        self.assertIn("Remote source differs", text)
        self.assertIn("package 1 -> 2", text)
        self.assertIn("Pin proposals require review", text)
        self.assertEqual(len(self.notifications()), 1)
        body = self.notifications()[0]["args"][-1]
        self.assertIn("Run: dotfiles-update", body)
        self.assertIn(str(self.report), body)

    def test_dirty_source_is_reported_without_snapshot(self):
        self.env["STUB_DIRTY_SOURCE"] = " M dot_zshrc.tmpl"
        self.assertEqual(self.run_check().returncode, 0)
        self.assertIn("Local source has pending changes", self.report.read_text())
        self.assertEqual(len(self.notifications()), 1)
        jj = [event for event in self.events() if event["command"] == "jj"]
        self.assertEqual(len(jj), 2)
        self.assertTrue(all("--ignore-working-copy" in event["args"] for event in jj))

    def test_optional_aur_check_is_reported_when_unavailable(self):
        (self.bin / "yay").unlink()
        self.assertEqual(self.run_check().returncode, 0)
        self.assertIn("Skipped: yay is not installed", self.report.read_text())

    def test_remote_network_failure_is_not_a_clean_result(self):
        self.env.update(STUB_REMOTE_FAILURE="1", STUB_HTTPS_FAILURE="1")
        self.assertEqual(self.run_check().returncode, 1)
        self.assertIn("[ERROR] Remote dotfiles HEAD", self.report.read_text())
        self.assertIn("SSH connection failed", self.report.read_text())
        self.assertIn("Public HTTPS connection failed", self.report.read_text())
        self.assertIn("Check incomplete", self.notifications()[0]["args"][-1])
        self.assertIn("chezmoi-bump", [event["command"] for event in self.events()])

    def test_ssh_failure_uses_read_only_public_https(self):
        self.env["STUB_REMOTE_FAILURE"] = "1"
        self.assertEqual(self.run_check().returncode, 0)
        self.assertIn("Used read-only public GitHub HTTPS", self.report.read_text())
        fallback = [event for event in self.events() if event["command"] == "git" and event["args"][:2] == ["-c", "credential.helper="]]
        self.assertEqual(len(fallback), 1)
        self.assertIn("https://github.com/example/dotfiles.git", fallback[0]["args"])

    def test_arch_error_is_not_no_updates(self):
        self.env.update(STUB_ARCH_CODE="1", STUB_ARCH_OUTPUT="Mirror unavailable")
        self.assertEqual(self.run_check().returncode, 1)
        self.assertIn("[ERROR] Official Arch packages", self.report.read_text())

    def test_aur_error_is_recorded(self):
        self.env.update(STUB_AUR_CODE="1", STUB_AUR_OUTPUT="AUR unavailable")
        self.assertEqual(self.run_check().returncode, 1)
        self.assertIn("[ERROR] AUR packages", self.report.read_text())

    def test_aur_empty_status_one_means_no_updates(self):
        self.env.update(STUB_AUR_CODE="1", STUB_AUR_OUTPUT="")
        self.assertEqual(self.run_check().returncode, 0)
        self.assertIn("No AUR package updates", self.report.read_text())
        self.assertNotIn("[ERROR] AUR packages", self.report.read_text())
        self.assertFalse(self.notifications())

    def test_aur_other_empty_failure_is_recorded(self):
        self.env.update(STUB_AUR_CODE="2", STUB_AUR_OUTPUT="")
        self.assertEqual(self.run_check().returncode, 1)
        self.assertIn("[ERROR] AUR packages", self.report.read_text())
        self.assertIn("yay exited with status 2", self.report.read_text())

    def test_pin_error_replaces_previous_success_report(self):
        self.assertEqual(self.run_check().returncode, 0)
        self.env["STUB_PIN_FAILURE"] = "1"
        self.assertEqual(self.run_check().returncode, 1)
        self.assertIn("[ERROR] Seven-day supported pin scan", self.report.read_text())
        self.assertIn("Release metadata is unavailable", self.report.read_text())
        self.assertFalse(list(self.state.glob(".pin-check-*")))

    def test_invalid_pin_report_fails(self):
        self.env["STUB_PIN_INVALID"] = "1"
        self.assertEqual(self.run_check().returncode, 1)
        self.assertIn("Cannot read the complete pin report", self.report.read_text())

    def test_incomplete_pin_report_fails(self):
        self.env["STUB_PIN_PARTIAL"] = "1"
        self.assertEqual(self.run_check().returncode, 1)
        self.assertIn("does not cover the dependency inventory exactly once", self.report.read_text())

    def test_duplicate_pin_report_fails(self):
        self.env["STUB_PIN_DUPLICATE"] = "1"
        self.assertEqual(self.run_check().returncode, 1)
        self.assertIn("does not cover the dependency inventory exactly once", self.report.read_text())

    def test_unmerged_helper_is_not_executed(self):
        self.helper.write_text("raise RuntimeError('Unmerged helper must not run')\n")
        self.assertEqual(self.run_check().returncode, 1)
        self.assertIn("source pin helper differs from merged trunk", self.report.read_text())
        self.assertNotIn("chezmoi-bump", [event["command"] for event in self.events()])

    def test_major_pin_review_needs_attention(self):
        self.env["STUB_PIN_STATE"] = "major_review"
        self.assertEqual(self.run_check().returncode, 0)
        self.assertEqual(len(self.notifications()), 1)

    def test_too_new_pins_do_not_request_installation(self):
        self.env["STUB_PIN_STATE"] = "too_new"
        self.assertEqual(self.run_check().returncode, 0)
        self.assertFalse(self.notifications())

    def test_source_path_fallback_and_legacy_override(self):
        self.env.pop("CHEZMOI_SOURCE_DIR")
        self.assertEqual(self.run_check().returncode, 0)
        self.assertIn("chezmoi", [event["command"] for event in self.events()])
        self.log.unlink()
        self.env["CHEZMOI_DIR"] = str(self.source)
        self.assertEqual(self.run_check().returncode, 0)
        self.assertNotIn("chezmoi", [event["command"] for event in self.events()])

    def test_conflicting_source_overrides_fail_closed(self):
        other = self.case / "other"
        other.mkdir()
        self.env["CHEZMOI_DIR"] = str(other)
        self.assertEqual(self.run_check().returncode, 1)
        self.assertIn("CHEZMOI_SOURCE_DIR and CHEZMOI_DIR conflict", self.report.read_text())
        self.assertNotIn("chezmoi-bump", [event["command"] for event in self.events()])

    def test_relative_source_is_rejected(self):
        self.env["CHEZMOI_SOURCE_DIR"] = "source"
        self.assertEqual(self.run_check().returncode, 1)
        self.assertIn("existing absolute directory", self.report.read_text())

    def test_nonroot_jj_source_is_rejected(self):
        self.env["STUB_JJ_ROOT"] = str(self.case)
        self.assertEqual(self.run_check().returncode, 1)
        self.assertIn("not the JJ workspace root", self.report.read_text())

    def test_hanging_command_is_bounded_and_reported(self):
        self.env["STUB_SLEEP_COMMAND"] = "checkupdates"
        self.assertEqual(self.run_check(timeout=0.5).returncode, 1)
        self.assertIn("checkupdates timed out", self.report.read_text())

    def test_state_symlink_is_rejected(self):
        self.state_root.mkdir()
        target = self.case / "outside"
        target.mkdir()
        self.state.symlink_to(target)
        result = self.run_check()
        self.assertEqual(result.returncode, 1)
        self.assertIn("not a symlink", result.stderr)
        self.assertEqual(list(target.iterdir()), [])

    def test_report_replacement_does_not_follow_symlink(self):
        self.state.mkdir(parents=True)
        unrelated = self.case / "unrelated"
        unrelated.write_text("Keep this file")
        self.report.symlink_to(unrelated)
        self.assertEqual(self.run_check().returncode, 0)
        self.assertFalse(self.report.is_symlink())
        self.assertEqual(unrelated.read_text(), "Keep this file")

    def test_help_and_invalid_arguments_do_not_run_checks(self):
        self.assertEqual(self.run_check(args=["--help"]).returncode, 0)
        self.assertEqual(self.run_check(args=["--install"]).returncode, 2)
        self.assertEqual(self.events(), [])
        self.assertFalse(self.state.exists())

    def test_missing_required_check_is_incomplete(self):
        (self.bin / "checkupdates").unlink()
        self.assertEqual(self.run_check().returncode, 1)
        self.assertIn("Cannot run checkupdates", self.report.read_text())

    def test_notification_failure_preserves_complete_report(self):
        self.env.update(STUB_REMOTE_HEAD="b" * 40, STUB_NOTIFY_CODE="1")
        result = self.run_check()
        self.assertEqual(result.returncode, 0)
        self.assertIn("Notification unavailable", result.stderr)
        self.assertTrue(self.report.is_file())


unittest.main(verbosity=2)
PY
