#!/usr/bin/env bash
# Shared file discovery and rendering for syntax and ShellCheck.

test_shell_files() {
    git -C "$REPO_ROOT" ls-files --cached --others --exclude-standard
}

render_test_template() {
    local source_file="$1" destination="$2"
    command -v chezmoi >/dev/null 2>&1 || return 1
    chezmoi --source "$REPO_ROOT" execute-template < "$REPO_ROOT/$source_file" > "$destination"
}
