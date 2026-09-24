#!/usr/bin/env python3
"""Exercise setup recovery without network access or host installations."""

import copy
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


def render(name):
    return subprocess.check_output(
        ["chezmoi", "--source", str(ROOT), "execute-template"],
        input=(ROOT / ".chezmoiscripts" / name).read_text(), text=True, timeout=15,
    )


def executable(path, contents):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(contents)
    path.chmod(0o755)


class SetupRecoveryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.claude = render("run_onchange_after_35-setup-claude-code.sh.tmpl")
        cls.hermes = render("run_after_39-setup-hermes-agent.sh.tmpl")

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.home = self.base / "home"
        self.bin = self.home / ".local/bin"
        self.bin.mkdir(parents=True)
        self.state = self.base / "state"
        self.helper = ROOT / "dot_local/private_lib/chezmoi-helpers.sh"
        lib = self.home / ".local/lib"
        lib.mkdir()
        shutil.copyfile(self.helper, lib / "chezmoi-helpers.sh")
        shutil.copytree(ROOT / "dot_local/private_lib/chezmoi", lib / "chezmoi")
        self.prefix = self.base / "npm"
        self.env = dict(os.environ, HOME=str(self.home), STATE_DIR=str(self.state),
                        PATH=f"{self.bin}:/usr/bin:/bin", VERBOSE="false",
                        GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null",
                        TRUST_ON_FIRST_USE_INSTALLERS="0", CHEZMOI_FORCE_UPDATE="0",
                        TEST_PREFIX=str(self.prefix), TEST_INSTALL_FAIL="0")
        self.env.pop("CHEZMOI_HELPERS_LOADED", None)
        executable(self.bin / "npm", '''#!/usr/bin/env bash
set -eu
case "$1" in
    -v) echo 11.9.0 ;;
    prefix) echo "$TEST_PREFIX" ;;
    install)
        touch "$HOME/install-called"
        if [ "$TEST_INSTALL_FAIL" = 1 ]; then
            echo 'fixture npm install error' >&2
            exit 1
        fi
        mkdir -p "$TEST_PREFIX/bin"
        printf '#!/bin/sh\necho "999.0.0 (Claude Code)"\n' > "$TEST_PREFIX/bin/claude"
        chmod +x "$TEST_PREFIX/bin/claude"
        ;;
    *) exit 2 ;;
esac
''')

    def run_bash(self, script):
        return subprocess.run(["/bin/bash", "-c", script], env=self.env,
                              capture_output=True, text=True, timeout=20)

    def broken_claude(self):
        old = self.home / ".nvm/versions/node/old/bin/claude"
        executable(old, '#!/bin/sh\necho "999.0.0 misleading output"\nexit 1\n')
        (self.bin / "claude").symlink_to(old)
        return old

    def test_broken_claude_is_repaired_and_repeat_is_noop(self):
        self.broken_claude()
        self.env["TRUST_ON_FIRST_USE_INSTALLERS"] = "1"
        result = self.run_bash(self.claude)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.bin / "claude").resolve(), self.prefix / "bin/claude")
        self.assertEqual(len(list(self.state.glob("claude-code-*.done"))), 1)
        (self.home / "install-called").unlink()
        result = self.run_bash(self.claude)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.home / "install-called").exists())

    def test_hermes_entrypoint_skips_disabled_install(self):
        result = self.run_bash(self.hermes)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertFalse((self.home / ".local/share/hermes-agent").exists())

    def test_hermes_entrypoint_retries_failed_sync_without_marking_ready(self):
        install = self.home / ".local/share/hermes-agent"
        venv_bin = install / ".venv/bin"
        venv_bin.mkdir(parents=True)
        (install / ".git").mkdir()
        hermes_ref = re.search(r'^HERMES_REF="([^"]+)"$', self.hermes, re.MULTILINE).group(1)
        executable(self.bin / "git", f'''#!/bin/sh
case "$*" in
    *"rev-parse HEAD") echo "{hermes_ref}" ;;
    *) exit 0 ;;
esac
''')
        executable(self.bin / "uv", '''#!/bin/sh
echo sync >> "$HOME/uv.log"
if [ "$UV_FAIL" = 1 ]; then echo 'fixture uv failure' >&2; exit 2; fi
exit 0
''')
        executable(venv_bin / "hermes", '''#!/bin/sh
case "$1" in
    --version) echo 'Hermes Agent 999.0.0' ;;
    config) exit 0 ;;
    *) exit 3 ;;
esac
''')
        (self.home / ".config/dotfiles").mkdir(parents=True)
        (self.home / ".config/dotfiles/hermes-agent.enabled").touch()
        (self.home / ".hermes").mkdir()
        (self.home / ".hermes/config.yaml").write_text("model: {}\n")
        self.env.update(UV_FAIL="1", TRUST_ON_FIRST_USE_INSTALLERS="1")
        failed = self.run_bash(self.hermes)
        self.assertEqual(failed.returncode, 2, failed.stdout + failed.stderr)
        self.assertIn("fixture uv failure", failed.stderr)
        self.assertFalse(list(self.state.glob("hermes-agent-env-*.done")))

        self.env["UV_FAIL"] = "0"
        succeeded = self.run_bash(self.hermes)
        self.assertEqual(succeeded.returncode, 0, succeeded.stdout + succeeded.stderr)
        self.assertTrue(list(self.state.glob("hermes-agent-env-*.done")))
        self.assertTrue(list(self.state.glob("hermes-agent-*.done")))
        self.assertEqual((self.home / "uv.log").read_text().splitlines(), ["sync", "sync"])

        repeated = self.run_bash(self.hermes)
        self.assertEqual(repeated.returncode, 0, repeated.stdout + repeated.stderr)
        self.assertEqual((self.home / "uv.log").read_text().splitlines(), ["sync", "sync"])

    def test_broken_claude_still_requires_trust(self):
        old = self.broken_claude()
        result = self.run_bash(self.claude)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("explicit trust", result.stdout)
        self.assertEqual((self.bin / "claude").resolve(), old)
        self.assertFalse((self.home / "install-called").exists())

    def test_force_repair_with_existing_state(self):
        self.broken_claude()
        pin = self.claude.split('PINNED_CLAUDE_NPM_VERSION="', 1)[1].split('"', 1)[0]
        self.state.mkdir()
        (self.state / f"claude-code-setup-{pin}.done").touch()
        self.env.update(TRUST_ON_FIRST_USE_INSTALLERS="1", CHEZMOI_FORCE_UPDATE="1")
        result = self.run_bash(self.claude)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.bin / "claude").resolve(), self.prefix / "bin/claude")

    def test_npm_local_prefix_does_not_create_self_link(self):
        self.broken_claude()
        self.env.update(TRUST_ON_FIRST_USE_INSTALLERS="1",
                        TEST_PREFIX=str(self.home / ".local"))
        result = self.run_bash(self.claude)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.run_bash('claude --version').returncode, 0)

    def test_working_npm_copy_repairs_link_without_download(self):
        self.broken_claude()
        executable(self.prefix / "bin/claude", '#!/bin/sh\necho "999.0.0 (Claude Code)"\n')
        result = self.run_bash(self.claude)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.bin / "claude").resolve(), self.prefix / "bin/claude")
        self.assertFalse((self.home / "install-called").exists())

    def test_install_failure_is_visible_and_preserves_old_link(self):
        old = self.broken_claude()
        self.env.update(TRUST_ON_FIRST_USE_INSTALLERS="1", TEST_INSTALL_FAIL="1")
        result = self.run_bash(self.claude)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fixture npm install error", result.stderr)
        self.assertEqual((self.bin / "claude").resolve(), old)
        self.assertFalse(list(self.state.glob("claude-code-*.done")))

    def init_hermes(self):
        self.checkout = self.base / "hermes"
        self.checkout.mkdir()
        self.git("init", "-q")
        self.lock = self.checkout / "package-lock.json"
        self.original = {"lockfileVersion": 3, "packages": {
            "node_modules/@esbuild/darwin-arm64": {"version": "1.0.0", "peer": True},
            "node_modules/other": {"version": "2.0.0", "peer": True},
        }}
        self.lock.write_text(json.dumps(self.original))
        self.git("add", "package-lock.json")
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                 "-c", "commit.gpgsign=false", "commit", "-qm", "fixture")
        self.legacy = copy.deepcopy(self.original)
        del self.legacy["packages"]["node_modules/@esbuild/darwin-arm64"]["peer"]
        self.lock.write_text(json.dumps(self.legacy))
        venv = self.base / "venv/bin"
        venv.mkdir(parents=True)
        (venv / "python").symlink_to(sys.executable)
        self.env.update(INSTALL_DIR=str(self.checkout), VENV_DIR=str(venv.parent))

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.checkout), *args],
                                       text=True, stderr=subprocess.STDOUT, env=self.env, timeout=15)

    def repair_lock(self):
        return self.run_bash(f'''set -euo pipefail
HERMES_LIB_DIR="{ROOT}/dot_local/private_lib/chezmoi/hermes"
. "{ROOT}/dot_local/private_lib/chezmoi/hermes/install.sh"
repair_hermes_npm_lock_metadata
''')

    def test_legacy_lock_repair_keeps_backup_and_is_idempotent(self):
        self.init_hermes()
        before = self.lock.read_bytes()
        result = self.repair_lock()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.git("status", "--porcelain"), "")
        backups = list(self.state.glob("hermes-package-lock-*.json"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), before)
        self.assertEqual(backups[0].stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.repair_lock().returncode, 0)
        self.assertEqual(list(self.state.glob("hermes-package-lock-*.json")), backups)

    def test_real_edits_staged_edits_and_untracked_files_are_preserved(self):
        for change in ("version", "other-peer", "staged", "untracked"):
            with self.subTest(change=change):
                # Each scenario uses an independent temporary checkout.
                with tempfile.TemporaryDirectory() as directory:
                    previous = self.base
                    self.base = Path(directory).resolve()
                    self.init_hermes()
                    if change == "version":
                        self.legacy["packages"]["node_modules/other"]["version"] = "3.0.0"
                    elif change == "other-peer":
                        del self.legacy["packages"]["node_modules/other"]["peer"]
                    self.lock.write_text(json.dumps(self.legacy))
                    if change == "staged":
                        self.git("add", "package-lock.json")
                    elif change == "untracked":
                        (self.checkout / "notes.txt").write_text("user work")
                    before = self.lock.read_bytes()
                    status = self.git("status", "--porcelain")
                    result = self.repair_lock()
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(self.lock.read_bytes(), before)
                    self.assertEqual(self.git("status", "--porcelain"), status)
                    self.assertFalse(list(self.state.glob("hermes-package-lock-*.json")))
                    self.base = previous

    def test_tui_install_uses_ci_and_reports_npm_errors(self):
        self.env.update(INSTALL_DIR=str(self.home), TUI_DIR=str(self.home),
                        HERMES_TUI_BY_DEFAULT="true")
        executable(self.bin / "npm", '''#!/bin/sh
[ "$1" = ci ] || exit 99
echo 'fixture ci failure' >&2
exit 1
''')
        result = self.run_bash('''set -euo pipefail
eecho() { echo "$@"; }
resolve_npm_cmd() { printf '%s\n' "$HOME/.local/bin/npm"; }
resolve_node_cmd() { echo /usr/bin/node; }
tui_npm_deps_ready() { return 1; }
require_trust_for_remote_download() { return 0; }
set +u
. "''' + str(ROOT / 'dot_local/private_lib/chezmoi/hermes/tui.sh') + '''"
set -u
ensure_hermes_tui_prebuilt
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fixture ci failure", result.stderr)

    def test_tui_failed_install_retries_then_builds_once(self):
        self.env.update(INSTALL_DIR=str(self.home), TUI_DIR=str(self.home),
                        HERMES_TUI_BY_DEFAULT="true", TEST_NPM_FAIL="1")
        executable(self.bin / "npm", '''#!/usr/bin/env bash
set -eu
case "$1" in
    ci)
        echo ci >> "$HOME/npm.log"
        if [ "$TEST_NPM_FAIL" = 1 ]; then echo 'fixture ci failure' >&2; exit 1; fi
        touch "$HOME/deps.ready"
        ;;
    run)
        echo build >> "$HOME/npm.log"
        touch "$HOME/build.ready"
        ;;
    *) exit 2 ;;
esac
''')
        script = f'''set -euo pipefail
eecho() {{ echo "$@"; }}
run_quiet() {{ "$@"; }}
resolve_npm_cmd() {{ printf '%s\\n' "$HOME/.local/bin/npm"; }}
resolve_node_cmd() {{ echo /usr/bin/node; }}
tui_npm_deps_ready() {{ [ -f "$HOME/deps.ready" ]; }}
tui_build_fresh() {{ [ -f "$HOME/build.ready" ]; }}
require_trust_for_remote_download() {{ return 0; }}
set +u
. "{ROOT}/dot_local/private_lib/chezmoi/hermes/tui.sh"
set -u
tui_npm_deps_ready() {{ [ -f "$HOME/deps.ready" ]; }}
tui_build_fresh() {{ [ -f "$HOME/build.ready" ]; }}
ensure_hermes_tui_prebuilt
'''
        failed = self.run_bash(script)
        self.assertNotEqual(failed.returncode, 0, failed.stdout + failed.stderr)
        self.assertFalse((self.home / "build.ready").exists())
        self.env["TEST_NPM_FAIL"] = "0"
        succeeded = self.run_bash(script)
        self.assertEqual(succeeded.returncode, 0, succeeded.stdout + succeeded.stderr)
        before = (self.home / "npm.log").read_text()
        repeated = self.run_bash(script)
        self.assertEqual(repeated.returncode, 0, repeated.stdout + repeated.stderr)
        self.assertEqual((self.home / "npm.log").read_text(), before)
        self.assertEqual(before.splitlines(), ["ci", "ci", "build"])

    def test_tui_repeat_patch_keeps_file_timestamp(self):
        target = self.home / "theme.ts"
        target.write_text("known line\n")
        before = target.stat().st_mtime_ns
        script = f'''set -eo pipefail
. "{ROOT}/dot_local/private_lib/chezmoi/hermes/tui.sh"
replace_hermes_tui_exact_line "{target}" "known line" "known line"
'''
        result = self.run_bash(script)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(target.stat().st_mtime_ns, before)

    def test_unknown_tui_theme_is_not_partly_rewritten(self):
        theme = self.home / "ui-tui/src/theme.ts"
        theme.parent.mkdir(parents=True)
        theme.write_text("    diffAdded: 'user color',\n"
                         "    diffRemoved: 'rgb(255,220,220)',\n")
        before = theme.read_bytes()
        self.env["INSTALL_DIR"] = str(self.home)
        result = self.run_bash(f'''set -eo pipefail
eecho() {{ echo "$@"; }}
vecho() {{ :; }}
. "{ROOT}/dot_local/private_lib/chezmoi/hermes/tui.sh"
ensure_hermes_tui_diff_color_patch
''')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("unknown layout", result.stdout)
        self.assertEqual(theme.read_bytes(), before)

    def test_supported_tui_theme_patch_is_repeatable(self):
        theme = self.home / "ui-tui/src/theme.ts"
        theme.parent.mkdir(parents=True)
        theme.write_text("\n".join((
            "    diffAdded: 'rgb(220,255,220)',",
            "    diffRemoved: 'rgb(255,220,220)',",
            "    diffAddedWord: 'rgb(36,138,61)',",
            "    diffRemovedWord: 'rgb(207,34,46)',",
            "    diffAdded: 'rgb(200,240,200)',",
            "    diffRemoved: 'rgb(240,200,200)',",
            "    diffAddedWord: 'rgb(27,94,32)',",
            "    diffRemovedWord: 'rgb(183,28,28)',",
        )) + "\n")
        self.env.update(INSTALL_DIR=str(self.home),
                        HERMES_TUI_DIFF_ADDED_BG="blue", HERMES_TUI_DIFF_REMOVED_BG="red",
                        HERMES_TUI_DIFF_ADDED_FG="cyan", HERMES_TUI_DIFF_REMOVED_FG="pink",
                        HERMES_TUI_DIFF_LIGHT_ADDED_BG="lightblue",
                        HERMES_TUI_DIFF_LIGHT_REMOVED_BG="lightred",
                        HERMES_TUI_DIFF_LIGHT_ADDED_FG="lightcyan",
                        HERMES_TUI_DIFF_LIGHT_REMOVED_FG="lightpink")
        script = f'''set -eo pipefail
eecho() {{ echo "$@"; }}
vecho() {{ :; }}
. "{ROOT}/dot_local/private_lib/chezmoi/hermes/tui.sh"
ensure_hermes_tui_diff_color_patch
'''
        result = self.run_bash(script)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("diffAdded: 'blue'", theme.read_text())
        before = (theme.read_bytes(), theme.stat().st_mtime_ns)
        result = self.run_bash(script)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((theme.read_bytes(), theme.stat().st_mtime_ns), before)

    def test_current_hermes_tui_layout_is_patched_and_reversible(self):
        theme = self.home / "ui-tui/src/theme.ts"
        app = self.home / "ui-tui/src/app/useMainApp.ts"
        chrome = self.home / "ui-tui/src/components/appChrome.tsx"
        for path in (theme, app, chrome):
            path.parent.mkdir(parents=True, exist_ok=True)
        theme.write_text("\n".join((
            "    diffAdded: 'rgb(31,37,33)',",
            "    diffRemoved: 'rgb(40,33,35)',",
            "    diffAddedWord: 'rgb(112,143,104)',",
            "    diffRemovedWord: 'rgb(166,100,104)',",
        )) + "\n")
        app.write_text("\n".join((
            "      // Let the cwd/branch label use a wider budget; the status rule still",
            "      // caps it to available right-side space, and the final Text truncates",
            "      // from the start so branch/repo context stays visible.",
            "      cwdLabel: fmtProjectCwdBranch(cwd, gitBranch, ui.info?.project?.name, 28),",
            "      voiceLabel: voiceRecording",
            "        ? '● REC'",
            "        : voiceProcessing",
            "          ? '◉ STT'",
            "          : `voice ${voiceEnabled ? 'on' : 'off'}${voiceTts ? ' [tts]' : ''}`",
        )) + "\n")
        chrome.write_text(
            '            <Text bold={!!sessionTitle} color={sessionTitle ? t.color.accent : t.color.label} wrap="truncate-end">\n'
        )
        self.env.update(
            INSTALL_DIR=str(self.home),
            HERMES_TUI_DIFF_ADDED_BG="rgb(31,37,33)",
            HERMES_TUI_DIFF_REMOVED_BG="rgb(40,33,35)",
            HERMES_TUI_DIFF_ADDED_FG="rgb(112,143,104)",
            HERMES_TUI_DIFF_REMOVED_FG="rgb(166,100,104)",
        )
        script = f'''set -eo pipefail
eecho() {{ echo "$@"; }}
vecho() {{ :; }}
. "{ROOT}/dot_local/private_lib/chezmoi/hermes/tui.sh"
ensure_hermes_tui_diff_color_patch
ensure_hermes_tui_status_patch
'''
        result = self.run_bash(script)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("Warning:", result.stdout)
        self.assertIn("fmtProjectCwdBranch(cwd, gitBranch, ui.info?.project?.name, 56)", app.read_text())
        self.assertIn("voiceEnabled ? `voice on${voiceTts ? ' [tts]' : ''}` : ''", app.read_text())
        self.assertIn('wrap="truncate-start"', chrome.read_text())
        before = tuple((path.read_bytes(), path.stat().st_mtime_ns) for path in (theme, app, chrome))
        repeated = self.run_bash(script)
        self.assertEqual(repeated.returncode, 0, repeated.stdout + repeated.stderr)
        self.assertEqual(tuple((path.read_bytes(), path.stat().st_mtime_ns) for path in (theme, app, chrome)), before)
        revert = f'''set -eo pipefail
eecho() {{ echo "$@"; }}
vecho() {{ :; }}
. "{ROOT}/dot_local/private_lib/chezmoi/hermes/tui.sh"
remove_hermes_tui_status_patch
'''
        reverted = self.run_bash(revert)
        self.assertEqual(reverted.returncode, 0, reverted.stdout + reverted.stderr)
        self.assertIn("fmtProjectCwdBranch(cwd, gitBranch, ui.info?.project?.name, 28)", app.read_text())
        self.assertIn("voice ${voiceEnabled ? 'on' : 'off'}", app.read_text())
        self.assertIn('wrap="truncate-end"', chrome.read_text())

    def test_unknown_tui_status_is_not_partly_rewritten(self):
        app = self.home / "ui-tui/src/app/useMainApp.ts"
        chrome = self.home / "ui-tui/src/components/appChrome.tsx"
        app.parent.mkdir(parents=True)
        chrome.parent.mkdir(parents=True)
        app.write_text("      voiceLabel: userOverride,\n"
                       "      cwdLabel: fmtCwdBranch(cwd, gitBranch, 28),\n")
        chrome.write_text('            <Text color={t.color.label} wrap="truncate-end">\n')
        before = (app.read_bytes(), chrome.read_bytes())
        self.env["INSTALL_DIR"] = str(self.home)
        result = self.run_bash(f'''set -eo pipefail
eecho() {{ echo "$@"; }}
vecho() {{ :; }}
. "{ROOT}/dot_local/private_lib/chezmoi/hermes/tui.sh"
ensure_hermes_tui_status_patch
''')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("unknown layout", result.stdout)
        self.assertEqual((app.read_bytes(), chrome.read_bytes()), before)

    def test_hermes_sync_failure_is_visible_and_does_not_mark_ready(self):
        self.env.update(INSTALL_DIR=str(self.home), VENV_DIR=str(self.home / ".venv"),
                        PYTHON_VERSION="3.12", HERMES_EXTRAS_KEY="messaging",
                        HERMES_ENV_STATE="hermes-env-test")
        setup = f'''set -euo pipefail
. "{self.helper}"
. "{ROOT}/dot_local/private_lib/chezmoi/hermes/install.sh"
HERMES_EXTRAS=(messaging)
require_trust_for_remote_download() {{ return 0; }}
'''
        executable(self.bin / "uv", '#!/bin/sh\necho "fixture uv failure" >&2\nexit 2\n')
        result = self.run_bash(setup + "\nif sync_hermes_environment; then exit 0; else exit $?; fi\n")
        self.assertEqual(result.returncode, 2)
        self.assertIn("fixture uv failure", result.stderr)
        self.assertFalse((self.state / "hermes-env-test.done").exists())
        executable(self.bin / "uv", '#!/bin/sh\nexit 0\n')
        result = self.run_bash(setup + "\nsync_hermes_environment\n")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.state / "hermes-env-test.done").exists())

    def test_hermes_version_alone_cannot_mark_environment_ready(self):
        executable(self.bin / "hermes", '#!/bin/sh\nexit 0\n')
        self.env.update(HERMES_ENV_STATE="hermes-env-test", HERMES_REF="fixture",
                        HERMES_BIN=str(self.bin / "hermes"), HERMES_HOME_DIR=str(self.home))
        setup = f'''set -euo pipefail
. "{self.helper}"
. "{ROOT}/dot_local/private_lib/chezmoi/hermes/install.sh"
hermes_current_ref() {{ echo fixture; }}
'''
        result = self.run_bash(setup + "\nhermes_ready\n")
        self.assertNotEqual(result.returncode, 0)
        self.state.mkdir()
        (self.state / "hermes-env-test.done").touch()
        self.assertEqual(self.run_bash(setup + "\nhermes_ready\n").returncode, 0)

    def test_hermes_extras_exclude_removed_cli_extra(self):
        extras = self.hermes.split("HERMES_EXTRAS=(", 1)[1].split(")", 1)[0]
        self.assertNotIn('"cli"', extras)


if __name__ == "__main__":
    unittest.main()
