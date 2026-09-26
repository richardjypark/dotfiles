#!/usr/bin/env python3
"""Exercise private-path, commit-identity, and pre-publication failure checks."""

import os
from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
TEMP_HELPER = ROOT / "tests/lib/temp.sh"
GUARD = ROOT / "scripts/check-public-files.py"
PUBLISH = ROOT / "dot_local/bin/executable_dotfiles-push"
PUBLIC_EMAIL = "test@users.noreply.github.com"


class PublicationGuards(unittest.TestCase):
    def setUp(self):
        made = subprocess.run(
            ["bash", "-c", '. "$1"; new_test_temp_dir task_dir; printf "%s" "$task_dir"',
             "test-temp", str(TEMP_HELPER)], capture_output=True, text=True, check=True)
        self.temp = Path(made.stdout)
        self.addCleanup(self.remove_temp)
        self.repo = self.temp / "repo"
        self.repo.mkdir()
        self.bin = self.temp / "bin"
        self.bin.mkdir()
        self.env = {**os.environ, "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull,
                    "GIT_AUTHOR_NAME": "test", "GIT_COMMITTER_NAME": "test",
                    "GIT_AUTHOR_EMAIL": PUBLIC_EMAIL, "GIT_COMMITTER_EMAIL": PUBLIC_EMAIL,
                    "PATH": f"{self.bin}{os.pathsep}{os.environ['PATH']}",
                    "GUARD_TEST_REPO": str(self.repo), "GUARD_TEST_LOG": str(self.temp / "calls")}
        for path in [".gitignore", "scripts/check-public-files.py", ".githooks/pre-commit",
                     ".githooks/pre-push", "dot_local/bin/executable_dotfiles-secret-scan"]:
            target = self.repo / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / path, target)
        self.run_ok("git", "init", "-q", "-b", "master")
        self.run_ok("git", "add", ".")
        self.run_ok("git", "commit", "-qm", "test: public base")
        self.base = self.run_ok("git", "rev-parse", "HEAD").stdout.strip()
        self.run_ok("git", "remote", "add", "origin", str(self.temp / "unused-remote"))
        self.run_ok("git", "update-ref", "refs/remotes/origin/master", self.base)
        self.write_tool("gitleaks", '#!/bin/sh\necho scan >> "$GUARD_TEST_LOG"\nexit "${GUARD_SCAN_EXIT:-0}"\n')
        self.write_tool("jj", '''#!/bin/sh
case "$1" in
  root) printf '%s\n' "$GUARD_TEST_REPO" ;;
  status) exit 0 ;;
  git) printf 'push %s\n' "$*" >> "$GUARD_TEST_LOG" ;;
  *) exit 9 ;;
esac
''')

    def remove_temp(self):
        subprocess.run(["bash", "-c", '. "$1"; remove_test_temp_dir "$2"',
                        "test-temp", str(TEMP_HELPER), str(self.temp)], check=True)

    def write_tool(self, name, content):
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)

    def run_command(self, *command, input=None, env=None):
        return subprocess.run(command, cwd=self.repo, env=env or self.env, input=input,
                              capture_output=True, text=True, timeout=60)

    def run_ok(self, *command, **kwargs):
        result = self.run_command(*command, **kwargs)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def commit_file(self, name, *, email=PUBLIC_EMAIL):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("public test fixture\n")
        self.run_ok("git", "add", "-f", "--", name)
        self.run_ok("git", "commit", "-qm", "test: fixture",
                    env={**self.env, "GIT_AUTHOR_EMAIL": email})

    def test_ignore_policy_covers_source_names_and_keeps_public_templates(self):
        blocked = [".env", "nested/.env", "private_dot_env", "dot_env.production",
                   "private_dot_ssh/private_id_ed25519", "private_dot_aws/private_credentials",
                   "private_dot_codex/private_auth.json", "private_dot_config/gh/private_hosts.yml",
                   "private_dot_npmrc", "private_dot_git-credentials", "private_dot_zsh_history"]
        allowed = [".claude/settings.local.json", "autoresearch.checks.sh",
                   "scripts/bootstrap-private-env.example", "private_dot_codex/private_config.toml.tmpl",
                   "encrypted_private_secrets.toml.age", "private_dot_config/shell/history.sh"]
        for name in blocked + allowed:
            result = self.run_command("git", "check-ignore", "--no-index", "-q", "--", name)
            self.assertEqual(result.returncode, 0 if name in blocked else 1, name)

    def test_forced_private_file_is_rejected_without_printing_content(self):
        name = "private_dot_ssh/private_id_ed25519"
        self.commit_file(name)
        result = self.run_command("python3", str(GUARD))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(name, result.stderr)
        self.assertNotIn("public test fixture", result.stderr)

    def test_intermediate_private_file_still_blocks_after_removal(self):
        name = "private_dot_ssh/private_id_ed25519"
        self.commit_file(name)
        self.run_ok("git", "rm", "-q", "--", name)
        self.run_ok("git", "commit", "-qm", "test: remove fixture")
        self.run_ok("python3", str(GUARD))
        result = self.run_command("python3", str(GUARD), "--remote", "origin")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(name, result.stderr)

    def test_personal_email_is_rejected_but_not_printed(self):
        personal = "person@example.com"
        self.commit_file("public.txt", email=personal)
        result = self.run_command("python3", str(GUARD), "--base", self.base)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no-reply", result.stderr)
        self.assertNotIn(personal, result.stderr)

    def test_public_commit_and_push_records_pass(self):
        self.commit_file("public.txt")
        head = self.run_ok("git", "rev-parse", "HEAD").stdout.strip()
        result = self.run_ok("python3", str(GUARD), "--pre-push", "origin",
                             input=f"refs/heads/master {head} refs/heads/master {self.base}\n")
        self.assertIn("1 outgoing commits", result.stdout)
        result = self.run_command("python3", str(GUARD), "--pre-push", "origin", input="invalid\n")
        self.assertNotEqual(result.returncode, 0)

    def test_git_hook_rejects_forced_path_before_scanning(self):
        self.commit_file("private_dot_ssh/private_id_ed25519")
        result = self.run_command("sh", ".githooks/pre-commit")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.temp / "calls").exists())

    def test_publisher_stops_on_scan_failure(self):
        self.commit_file("public.txt")
        result = self.run_command("bash", str(PUBLISH), "-b", "master",
                                  env={**self.env, "GUARD_SCAN_EXIT": "23"})
        self.assertEqual(result.returncode, 23, result.stdout + result.stderr)
        self.assertNotIn("push ", (self.temp / "calls").read_text())

    def test_publisher_preserves_exact_bookmark_and_dry_run(self):
        self.commit_file("public.txt")
        self.run_ok("bash", str(PUBLISH), "--bookmark", "master", "--remote", "origin", "--dry-run")
        calls = (self.temp / "calls").read_text().splitlines()
        self.assertEqual(calls[:2], ["scan", "scan"])
        self.assertEqual(calls[-1], "push git push --ignore-working-copy --remote origin --bookmark exact:master --dry-run")

    def test_publisher_without_dry_run_works_in_system_bash(self):
        self.commit_file("public.txt")
        self.run_ok("/bin/bash", str(PUBLISH), "--bookmark", "master", "--remote", "origin")
        calls = (self.temp / "calls").read_text().splitlines()
        self.assertEqual(calls[:2], ["scan", "scan"])
        self.assertEqual(calls[-1], "push git push --ignore-working-copy --remote origin --bookmark exact:master")

    def test_publisher_rejects_unscanned_repository_and_broad_push_options(self):
        for args in [[], ["--all"], ["-b", "master", "--repository", str(self.temp)],
                     ["-b", "master", "-b", "another"]]:
            with self.subTest(args=args):
                result = self.run_command("bash", str(PUBLISH), *args)
                self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.temp / "calls").exists())


if __name__ == "__main__":
    unittest.main()
