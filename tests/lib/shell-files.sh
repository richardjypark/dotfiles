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

# render_test_templates DEST FILE...: render each source FILE to DEST/FILE.
# Every chezmoi process reads the whole source tree, ignored node_modules
# included, so one process renders all files. If the batch fails, each file
# renders alone so the error names it; a file that fails is absent from DEST.
render_test_templates() {
    local dest="$1" boundary="@@chezmoi-test-render-boundary@@" file template=""
    shift
    [ "$#" -gt 0 ] || return 0
    command -v chezmoi >/dev/null 2>&1 || return 1
    for file in "$@"; do
        template="$template{{ includeTemplate \"$file\" . }}"$'\n'"$boundary"$'\n'
        mkdir -p "$(dirname "$dest/$file")"
        : > "$dest/$file"
    done
    if chezmoi --source "$REPO_ROOT" execute-template "$template" > "$dest.batch" 2>/dev/null \
        && [ "$(grep -cxF "$boundary" "$dest.batch")" -eq "$#" ] \
        && printf '%s\n' "$@" | awk -v dest="$dest" -v boundary="$boundary" '
            NR == FNR { files[NR] = dest "/" $0; next }
            $0 == boundary { close(files[++part]); next }
            { print >> files[part + 1] }' - "$dest.batch"; then
        rm -f "$dest.batch"
        return 0
    fi
    rm -f "$dest.batch"
    for file in "$@"; do
        render_test_template "$file" "$dest/$file" || rm -f "$dest/$file"
    done
}
