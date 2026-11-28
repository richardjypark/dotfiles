#!/usr/bin/env python3
"""PreToolUse hook: bundle the repo outside the working tree before a command that can delete it.

AGENTS.md requires a backup before ./tests/all, a setup script, or chezmoi apply. A test run
once deleted the working tree, so the harness makes the bundle instead of the model.
Exit 2 blocks the command when the bundle cannot be made.

Hooks run outside the sandbox, so this hook runs only git: the sandbox cannot write
.git/config, but it can write repo scripts, jj repo config, and .githooks/, which this
clone's core.hooksPath names. Every git call turns hooks and fsmonitor off, because
`git add` and `git update-ref` would otherwise run hook files from there.
A temporary index records uncommitted and untracked files under refs/dotfiles-backup/,
which jj does not import. Each git call times out well inside the hook timeout, so a
slow backup exits 2 here instead of letting the command run without one.
"""

from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
import time
from pathlib import Path

KEEP = 10
GIT_TIMEOUT = 30
SAFE_GIT = ("-c", "core.hooksPath=/dev/null", "-c", "core.fsmonitor=false")
SNAPSHOT_REF = "refs/dotfiles-backup/working-tree"
WRAPPERS = {"sudo", "env", "time", "nice", "nohup", "command", "exec", "bash", "sh", "zsh"}
SETUP_SCRIPT = re.compile(r"^(bootstrap-[\w-]+|server-lockdown-[\w-]+|setup-[\w-]+)\.sh$")
CHEZMOI_WRITES = {"apply", "update", "init", "purge", "destroy"}


def subcommands(command: str) -> list[list[str]]:
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|()")
    lexer.whitespace_split = True
    words, current = [], []
    try:
        for token in lexer:
            if token and set(token) <= set(";&|()"):
                words.append(current)
                current = []
            else:
                current.append(token)
    except ValueError:
        return [command.split()]
    words.append(current)
    return [word for word in words if word]


def program(words: list[str]) -> list[str]:
    while words and (words[0] in WRAPPERS or "=" in words[0] or words[0].startswith("-")):
        words = words[1:]
    return words


def risky(command: str) -> bool:
    for words in subcommands(command):
        words = program(words)
        if not words:
            continue
        path = Path(words[0])
        if path.name == "all" and path.parent.name == "tests":
            return True
        if path.name == "chezmoi" and any(word in CHEZMOI_WRITES for word in words[1:]):
            if not any(word in ("--dry-run", "-n") for word in words[1:]):
                return True
        if SETUP_SCRIPT.match(path.name) or ".chezmoiscripts" in path.parts:
            return True
    return False


def backup_dir() -> Path:
    if os.environ.get("DOTFILES_BACKUP_DIR"):
        return Path(os.environ["DOTFILES_BACKUP_DIR"])
    state = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local/state")
    return Path(state) / "dotfiles-backups"


def git(repo: Path, *args: str, env: dict | None = None) -> str:
    return subprocess.run(["git", "-C", str(repo), *SAFE_GIT, *args], capture_output=True, text=True,
                          timeout=GIT_TIMEOUT, check=True, env=env).stdout.strip()


def snapshot_working_tree(repo: Path) -> None:
    with tempfile.TemporaryDirectory() as directory:
        env = {**os.environ, "GIT_INDEX_FILE": str(Path(directory) / "index"),
               "GIT_AUTHOR_NAME": "dotfiles backup", "GIT_AUTHOR_EMAIL": "backup@localhost",
               "GIT_COMMITTER_NAME": "dotfiles backup", "GIT_COMMITTER_EMAIL": "backup@localhost"}
        git(repo, "add", "--all", env=env)
        tree = git(repo, "write-tree", env=env)
        parents = []
        try:
            parents = ["-p", git(repo, "rev-parse", "--verify", "HEAD")]
        except subprocess.CalledProcessError:
            pass
        commit = git(repo, "commit-tree", tree, *parents, "-m", "dotfiles backup: working tree", env=env)
        git(repo, "update-ref", SNAPSHOT_REF, commit)


def bundle(repo: Path) -> Path:
    os.umask(0o077)
    target = backup_dir()
    target.mkdir(mode=0o700, parents=True, exist_ok=True)
    target.chmod(0o700)
    snapshot_working_tree(repo)
    path = target / f"dotfiles-{time.strftime('%Y%m%d-%H%M%S')}-{os.getpid()}.bundle"
    git(repo, "bundle", "create", str(path), "--all")
    for old in sorted(target.glob("dotfiles-*.bundle"), key=lambda p: p.stat().st_mtime)[:-KEEP]:
        old.unlink()
    return path


def main() -> int:
    event = json.load(sys.stdin)
    command = event.get("tool_input", {}).get("command", "")
    if not risky(command):
        return 0
    repo = Path(os.environ.get("CLAUDE_PROJECT_DIR") or event.get("cwd") or os.getcwd())
    try:
        path = bundle(repo)
    except (OSError, subprocess.SubprocessError) as error:
        detail = getattr(error, "stderr", "") or error
        print(f"Blocked: the backup bundle for {repo} failed ({detail}). "
              "Save the work outside the repo first (AGENTS.md, Backup).", file=sys.stderr)
        return 2
    print(json.dumps({"systemMessage": f"Backup bundle: {path}"}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
