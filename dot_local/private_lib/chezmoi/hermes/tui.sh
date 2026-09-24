HERMES_TUI_DIFF_THEME_FILE="ui-tui/src/theme.ts"
HERMES_TUI_DIFF_DARK_UPSTREAM_ADDED="    diffAdded: 'rgb(220,255,220)',"
HERMES_TUI_DIFF_DARK_UPSTREAM_REMOVED="    diffRemoved: 'rgb(255,220,220)',"
HERMES_TUI_DIFF_DARK_UPSTREAM_ADDED_WORD="    diffAddedWord: 'rgb(36,138,61)',"
HERMES_TUI_DIFF_DARK_UPSTREAM_REMOVED_WORD="    diffRemovedWord: 'rgb(207,34,46)',"
HERMES_TUI_DIFF_LIGHT_UPSTREAM_ADDED="    diffAdded: 'rgb(200,240,200)',"
HERMES_TUI_DIFF_LIGHT_UPSTREAM_REMOVED="    diffRemoved: 'rgb(240,200,200)',"
HERMES_TUI_DIFF_LIGHT_UPSTREAM_ADDED_WORD="    diffAddedWord: 'rgb(27,94,32)',"
HERMES_TUI_DIFF_LIGHT_UPSTREAM_REMOVED_WORD="    diffRemovedWord: 'rgb(183,28,28)',"
HERMES_TUI_DIFF_DARK_PATCH_ADDED="    diffAdded: '$HERMES_TUI_DIFF_ADDED_BG',"
HERMES_TUI_DIFF_DARK_PATCH_REMOVED="    diffRemoved: '$HERMES_TUI_DIFF_REMOVED_BG',"
HERMES_TUI_DIFF_DARK_PATCH_ADDED_WORD="    diffAddedWord: '$HERMES_TUI_DIFF_ADDED_FG',"
HERMES_TUI_DIFF_DARK_PATCH_REMOVED_WORD="    diffRemovedWord: '$HERMES_TUI_DIFF_REMOVED_FG',"
HERMES_TUI_DIFF_LIGHT_PATCH_ADDED="    diffAdded: '$HERMES_TUI_DIFF_LIGHT_ADDED_BG',"
HERMES_TUI_DIFF_LIGHT_PATCH_REMOVED="    diffRemoved: '$HERMES_TUI_DIFF_LIGHT_REMOVED_BG',"
HERMES_TUI_DIFF_LIGHT_PATCH_ADDED_WORD="    diffAddedWord: '$HERMES_TUI_DIFF_LIGHT_ADDED_FG',"
HERMES_TUI_DIFF_LIGHT_PATCH_REMOVED_WORD="    diffRemovedWord: '$HERMES_TUI_DIFF_LIGHT_REMOVED_FG',"
HERMES_TUI_DIFF_SKIN_NATIVE_ADDED="    diffAdded: c('diff_added') ?? derived.diffAdded,"
HERMES_TUI_DIFF_SKIN_NATIVE_REMOVED="    diffRemoved: c('diff_removed') ?? derived.diffRemoved,"
HERMES_TUI_DIFF_SKIN_NATIVE_ADDED_WORD="    diffAddedWord: c('diff_added_word') ?? derived.diffAddedWord,"
HERMES_TUI_DIFF_SKIN_NATIVE_REMOVED_WORD="    diffRemovedWord: c('diff_removed_word') ?? derived.diffRemovedWord,"

HERMES_TUI_STATUS_FILE="ui-tui/src/app/useMainApp.ts"
HERMES_TUI_STATUS_UPSTREAM_VOICE_LABEL="      voiceLabel: voiceRecording ? '● REC' : voiceProcessing ? '◉ STT' : \`voice \${voiceEnabled ? 'on' : 'off'}\${voiceTts ? ' [tts]' : ''}\`"
HERMES_TUI_STATUS_LEGACY_PATCH_VOICE_LABEL="      voiceLabel: voiceRecording ? '● REC' : voiceProcessing ? '◉ STT' : voiceEnabled ? 'voice on' : ''"
HERMES_TUI_STATUS_PATCH_VOICE_LABEL="      voiceLabel: voiceRecording ? '● REC' : voiceProcessing ? '◉ STT' : voiceEnabled ? ('voice on' + (voiceTts ? ' [tts]' : '')) : ''"
HERMES_TUI_STATUS_CHROME_FILE="ui-tui/src/components/appChrome.tsx"
HERMES_TUI_STATUS_UPSTREAM_CWD_COMMENT_1="      // Cap the status-bar cwd/branch label tighter than the shared default so"
HERMES_TUI_STATUS_UPSTREAM_CWD_COMMENT_2="      // it doesn't dominate the bar; the status rule reserves the left-side"
HERMES_TUI_STATUS_UPSTREAM_CWD_COMMENT_3="      // essentials and truncates this further on narrow terminals."
HERMES_TUI_STATUS_PATCH_CWD_COMMENT_1="      // Let the cwd/branch label use a wider budget; the status rule still"
HERMES_TUI_STATUS_PATCH_CWD_COMMENT_2="      // caps it to available right-side space, and the final Text truncates"
HERMES_TUI_STATUS_PATCH_CWD_COMMENT_3="      // from the start so branch/repo context stays visible."
HERMES_TUI_STATUS_UPSTREAM_CWD_LABEL="      cwdLabel: fmtCwdBranch(cwd, gitBranch, 28),"
HERMES_TUI_STATUS_PATCH_CWD_LABEL="      cwdLabel: fmtCwdBranch(cwd, gitBranch, 56),"
HERMES_TUI_STATUS_UPSTREAM_CWD_WRAP='            <Text color={t.color.label} wrap="truncate-end">'
HERMES_TUI_STATUS_PATCH_CWD_WRAP='            <Text color={t.color.label} wrap="truncate-start">'
HERMES_TUI_STATUS_CURRENT_CWD_LABEL="      cwdLabel: fmtProjectCwdBranch(cwd, gitBranch, ui.info?.project?.name, 28),"
HERMES_TUI_STATUS_CURRENT_PATCH_CWD_LABEL="      cwdLabel: fmtProjectCwdBranch(cwd, gitBranch, ui.info?.project?.name, 56),"
HERMES_TUI_STATUS_CURRENT_CWD_WRAP='            <Text bold={!!sessionTitle} color={sessionTitle ? t.color.accent : t.color.label} wrap="truncate-end">'
HERMES_TUI_STATUS_CURRENT_PATCH_CWD_WRAP='            <Text bold={!!sessionTitle} color={sessionTitle ? t.color.accent : t.color.label} wrap="truncate-start">'
HERMES_TUI_STATUS_CURRENT_VOICE_TAIL="          : \`voice \${voiceEnabled ? 'on' : 'off'}\${voiceTts ? ' [tts]' : ''}\`"
HERMES_TUI_STATUS_CURRENT_PATCH_VOICE_TAIL="          : voiceEnabled ? \`voice on\${voiceTts ? ' [tts]' : ''}\` : ''"

HERMES_TUI_GIT_BRANCH_FILE="ui-tui/src/hooks/useGitBranch.ts"

tui_line_is_known() {
    local file="$1" original="$2" managed="$3"
    grep -Fqx "$original" "$file" || grep -Fqx "$managed" "$file"
}

tui_diff_layout_known() {
    local file="$INSTALL_DIR/$HERMES_TUI_DIFF_THEME_FILE"
    tui_line_is_known "$file" "$HERMES_TUI_DIFF_DARK_UPSTREAM_ADDED" "$HERMES_TUI_DIFF_DARK_PATCH_ADDED" || return 1
    tui_line_is_known "$file" "$HERMES_TUI_DIFF_DARK_UPSTREAM_REMOVED" "$HERMES_TUI_DIFF_DARK_PATCH_REMOVED" || return 1
    tui_line_is_known "$file" "$HERMES_TUI_DIFF_DARK_UPSTREAM_ADDED_WORD" "$HERMES_TUI_DIFF_DARK_PATCH_ADDED_WORD" || return 1
    tui_line_is_known "$file" "$HERMES_TUI_DIFF_DARK_UPSTREAM_REMOVED_WORD" "$HERMES_TUI_DIFF_DARK_PATCH_REMOVED_WORD" || return 1
    tui_line_is_known "$file" "$HERMES_TUI_DIFF_LIGHT_UPSTREAM_ADDED" "$HERMES_TUI_DIFF_LIGHT_PATCH_ADDED" || return 1
    tui_line_is_known "$file" "$HERMES_TUI_DIFF_LIGHT_UPSTREAM_REMOVED" "$HERMES_TUI_DIFF_LIGHT_PATCH_REMOVED" || return 1
    tui_line_is_known "$file" "$HERMES_TUI_DIFF_LIGHT_UPSTREAM_ADDED_WORD" "$HERMES_TUI_DIFF_LIGHT_PATCH_ADDED_WORD" || return 1
    tui_line_is_known "$file" "$HERMES_TUI_DIFF_LIGHT_UPSTREAM_REMOVED_WORD" "$HERMES_TUI_DIFF_LIGHT_PATCH_REMOVED_WORD"
}

tui_diff_skin_native() {
    local file="$INSTALL_DIR/$HERMES_TUI_DIFF_THEME_FILE"
    grep -Fqx "$HERMES_TUI_DIFF_SKIN_NATIVE_ADDED" "$file" \
        && grep -Fqx "$HERMES_TUI_DIFF_SKIN_NATIVE_REMOVED" "$file" \
        && grep -Fqx "$HERMES_TUI_DIFF_SKIN_NATIVE_ADDED_WORD" "$file" \
        && grep -Fqx "$HERMES_TUI_DIFF_SKIN_NATIVE_REMOVED_WORD" "$file"
}

tui_diff_skin_managed_ready() {
    local file="$INSTALL_DIR/$HERMES_TUI_DIFF_THEME_FILE"
    grep -Fqx "$HERMES_TUI_DIFF_DARK_PATCH_ADDED" "$file" \
        && grep -Fqx "$HERMES_TUI_DIFF_DARK_PATCH_REMOVED" "$file" \
        && grep -Fqx "$HERMES_TUI_DIFF_DARK_PATCH_ADDED_WORD" "$file" \
        && grep -Fqx "$HERMES_TUI_DIFF_DARK_PATCH_REMOVED_WORD" "$file"
}

replace_hermes_tui_diff_color_lines() {
    local mode="$1"
    local theme_file="$INSTALL_DIR/$HERMES_TUI_DIFF_THEME_FILE"
    [ -f "$theme_file" ] || return 0
    if ! tui_diff_layout_known; then
        eecho "Warning: Hermes TUI diff theme has an unknown layout; leaving it unchanged."
        return 0
    fi

    local tmp awk_status
    tmp="$(mktemp "${theme_file}.tmp.XXXXXX")" || return 1
    if awk \
        -v mode="$mode" \
        -v dark_added_patch="$HERMES_TUI_DIFF_DARK_PATCH_ADDED" \
        -v dark_removed_patch="$HERMES_TUI_DIFF_DARK_PATCH_REMOVED" \
        -v dark_added_word_patch="$HERMES_TUI_DIFF_DARK_PATCH_ADDED_WORD" \
        -v dark_removed_word_patch="$HERMES_TUI_DIFF_DARK_PATCH_REMOVED_WORD" \
        -v light_added_patch="$HERMES_TUI_DIFF_LIGHT_PATCH_ADDED" \
        -v light_removed_patch="$HERMES_TUI_DIFF_LIGHT_PATCH_REMOVED" \
        -v light_added_word_patch="$HERMES_TUI_DIFF_LIGHT_PATCH_ADDED_WORD" \
        -v light_removed_word_patch="$HERMES_TUI_DIFF_LIGHT_PATCH_REMOVED_WORD" \
        -v dark_added_upstream="$HERMES_TUI_DIFF_DARK_UPSTREAM_ADDED" \
        -v dark_removed_upstream="$HERMES_TUI_DIFF_DARK_UPSTREAM_REMOVED" \
        -v dark_added_word_upstream="$HERMES_TUI_DIFF_DARK_UPSTREAM_ADDED_WORD" \
        -v dark_removed_word_upstream="$HERMES_TUI_DIFF_DARK_UPSTREAM_REMOVED_WORD" \
        -v light_added_upstream="$HERMES_TUI_DIFF_LIGHT_UPSTREAM_ADDED" \
        -v light_removed_upstream="$HERMES_TUI_DIFF_LIGHT_UPSTREAM_REMOVED" \
        -v light_added_word_upstream="$HERMES_TUI_DIFF_LIGHT_UPSTREAM_ADDED_WORD" \
        -v light_removed_word_upstream="$HERMES_TUI_DIFF_LIGHT_UPSTREAM_REMOVED_WORD" '
        BEGIN {
            if (mode == "apply") {
                wanted["added", 1] = dark_added_patch
                wanted["removed", 1] = dark_removed_patch
                wanted["added_word", 1] = dark_added_word_patch
                wanted["removed_word", 1] = dark_removed_word_patch
                wanted["added", 2] = light_added_patch
                wanted["removed", 2] = light_removed_patch
                wanted["added_word", 2] = light_added_word_patch
                wanted["removed_word", 2] = light_removed_word_patch
            } else if (mode == "revert") {
                wanted["added", 1] = dark_added_upstream
                wanted["removed", 1] = dark_removed_upstream
                wanted["added_word", 1] = dark_added_word_upstream
                wanted["removed_word", 1] = dark_removed_word_upstream
                wanted["added", 2] = light_added_upstream
                wanted["removed", 2] = light_removed_upstream
                wanted["added_word", 2] = light_added_word_upstream
                wanted["removed_word", 2] = light_removed_word_upstream
            } else {
                exit 2
            }
        }
        function emit(kind, ordinal, replacement) {
            replacement = wanted[kind, ordinal]
            if (replacement != "") {
                print replacement
                changed = 1
                return 1
            }
            return 0
        }
        /^    diffAdded: / { added++; if (emit("added", added)) next }
        /^    diffRemoved: / { removed++; if (emit("removed", removed)) next }
        /^    diffAddedWord: / { added_word++; if (emit("added_word", added_word)) next }
        /^    diffRemovedWord: / { removed_word++; if (emit("removed_word", removed_word)) next }
        { print }
        END { if (changed) exit 42 }
    ' "$theme_file" > "$tmp"; then
        rm -f "$tmp"
        return 0
    else
        awk_status=$?
        if [ "$awk_status" -eq 42 ]; then
            if cmp -s "$tmp" "$theme_file"; then
                rm -f "$tmp"
            else
                mv "$tmp" "$theme_file"
            fi
            return 0
        fi
        rm -f "$tmp"
        return "$awk_status"
    fi
}

tui_diff_colors_ready() {
    local theme_file="$INSTALL_DIR/$HERMES_TUI_DIFF_THEME_FILE"
    [ -f "$theme_file" ] || return 1
    if tui_diff_skin_native || tui_diff_skin_managed_ready; then
        return 0
    fi
    grep -Fqx "$HERMES_TUI_DIFF_DARK_PATCH_ADDED" "$theme_file" || return 1
    grep -Fqx "$HERMES_TUI_DIFF_DARK_PATCH_REMOVED" "$theme_file" || return 1
    grep -Fqx "$HERMES_TUI_DIFF_DARK_PATCH_ADDED_WORD" "$theme_file" || return 1
    grep -Fqx "$HERMES_TUI_DIFF_DARK_PATCH_REMOVED_WORD" "$theme_file" || return 1
    grep -Fqx "$HERMES_TUI_DIFF_LIGHT_PATCH_ADDED" "$theme_file" || return 1
    grep -Fqx "$HERMES_TUI_DIFF_LIGHT_PATCH_REMOVED" "$theme_file" || return 1
    grep -Fqx "$HERMES_TUI_DIFF_LIGHT_PATCH_ADDED_WORD" "$theme_file" || return 1
    grep -Fqx "$HERMES_TUI_DIFF_LIGHT_PATCH_REMOVED_WORD" "$theme_file" || return 1
}

ensure_hermes_tui_diff_color_patch() {
    local theme_file="$INSTALL_DIR/$HERMES_TUI_DIFF_THEME_FILE"
    [ -f "$theme_file" ] || return 0
    tui_diff_colors_ready && return 0
    # New Hermes themes resolve diff colors from the active skin and derived
    # palette. Keep that native behavior instead of forcing static colors.
    tui_diff_skin_native && return 0
    # A local skin may already contain the configured palette in the new
    # single-skin layout. It is ready; do not require removed light/dark slots.
    tui_diff_skin_managed_ready && return 0

    replace_hermes_tui_diff_color_lines apply
    if tui_diff_colors_ready; then
        vecho "Hermes TUI diff highlight colors patched"
    else
        eecho "Warning: Hermes TUI diff color patch could not be applied; upstream theme may have changed."
    fi
}

remove_hermes_tui_diff_color_patch() {
    replace_hermes_tui_diff_color_lines revert
}

hermes_tui_status_head_voice_label() {
    local line
    line="$(git -C "$INSTALL_DIR" show "HEAD:$HERMES_TUI_STATUS_FILE" 2>/dev/null \
        | grep -F "      voiceLabel:" \
        | head -n 1 || true)"
    if [ -n "$line" ]; then
        printf '%s\n' "$line"
    else
        printf '%s\n' "$HERMES_TUI_STATUS_UPSTREAM_VOICE_LABEL"
    fi
}

replace_hermes_tui_status_voice_line() {
    local mode="$1"
    local status_file="$INSTALL_DIR/$HERMES_TUI_STATUS_FILE"
    [ -f "$status_file" ] || return 0

    local from_line alternate_from_line to_line
    alternate_from_line=""
    case "$mode" in
        apply)
            replace_hermes_tui_exact_line "$status_file" \
                "$HERMES_TUI_STATUS_CURRENT_VOICE_TAIL" \
                "$HERMES_TUI_STATUS_CURRENT_PATCH_VOICE_TAIL"
            from_line="$HERMES_TUI_STATUS_UPSTREAM_VOICE_LABEL"
            alternate_from_line="$HERMES_TUI_STATUS_LEGACY_PATCH_VOICE_LABEL"
            to_line="$HERMES_TUI_STATUS_PATCH_VOICE_LABEL"
            ;;
        revert)
            replace_hermes_tui_exact_line "$status_file" \
                "$HERMES_TUI_STATUS_CURRENT_PATCH_VOICE_TAIL" \
                "$HERMES_TUI_STATUS_CURRENT_VOICE_TAIL"
            from_line="$HERMES_TUI_STATUS_PATCH_VOICE_LABEL"
            alternate_from_line="$HERMES_TUI_STATUS_LEGACY_PATCH_VOICE_LABEL"
            to_line="$(hermes_tui_status_head_voice_label)"
            ;;
        *)
            return 1
            ;;
    esac

    local tmp awk_status
    tmp="$(mktemp "${status_file}.tmp.XXXXXX")" || return 1
    if awk -v from_line="$from_line" -v alternate_from_line="$alternate_from_line" -v to_line="$to_line" '
        $0 == from_line || (alternate_from_line != "" && $0 == alternate_from_line) { print to_line; changed = 1; next }
        { print }
        END { if (changed) exit 42 }
    ' "$status_file" > "$tmp"; then
        rm -f "$tmp"
        return 0
    else
        awk_status=$?
        if [ "$awk_status" -eq 42 ]; then
            if cmp -s "$tmp" "$status_file"; then
                rm -f "$tmp"
            else
                mv "$tmp" "$status_file"
            fi
            return 0
        fi
        rm -f "$tmp"
        return "$awk_status"
    fi
}

replace_hermes_tui_exact_line() {
    local file="$1"
    local from_line="$2"
    local to_line="$3"
    [ -f "$file" ] || return 0

    local tmp awk_status
    tmp="$(mktemp "${file}.tmp.XXXXXX")" || return 1
    if awk -v from_line="$from_line" -v to_line="$to_line" '
        $0 == from_line { print to_line; changed = 1; next }
        { print }
        END { if (changed) exit 42 }
    ' "$file" > "$tmp"; then
        rm -f "$tmp"
        return 0
    else
        awk_status=$?
        if [ "$awk_status" -eq 42 ]; then
            if cmp -s "$tmp" "$file"; then
                rm -f "$tmp"
            else
                mv "$tmp" "$file"
            fi
            return 0
        fi
        rm -f "$tmp"
        return "$awk_status"
    fi
}

replace_hermes_tui_status_cwd_lines() {
    local mode="$1"
    local app_file="$INSTALL_DIR/$HERMES_TUI_STATUS_FILE"
    local chrome_file="$INSTALL_DIR/$HERMES_TUI_STATUS_CHROME_FILE"

    case "$mode" in
        apply)
            replace_hermes_tui_exact_line "$app_file" "$HERMES_TUI_STATUS_UPSTREAM_CWD_COMMENT_1" "$HERMES_TUI_STATUS_PATCH_CWD_COMMENT_1"
            replace_hermes_tui_exact_line "$app_file" "$HERMES_TUI_STATUS_UPSTREAM_CWD_COMMENT_2" "$HERMES_TUI_STATUS_PATCH_CWD_COMMENT_2"
            replace_hermes_tui_exact_line "$app_file" "$HERMES_TUI_STATUS_UPSTREAM_CWD_COMMENT_3" "$HERMES_TUI_STATUS_PATCH_CWD_COMMENT_3"
            replace_hermes_tui_exact_line "$app_file" "$HERMES_TUI_STATUS_UPSTREAM_CWD_LABEL" "$HERMES_TUI_STATUS_PATCH_CWD_LABEL"
            replace_hermes_tui_exact_line "$app_file" "$HERMES_TUI_STATUS_CURRENT_CWD_LABEL" "$HERMES_TUI_STATUS_CURRENT_PATCH_CWD_LABEL"
            replace_hermes_tui_exact_line "$chrome_file" "$HERMES_TUI_STATUS_UPSTREAM_CWD_WRAP" "$HERMES_TUI_STATUS_PATCH_CWD_WRAP"
            replace_hermes_tui_exact_line "$chrome_file" "$HERMES_TUI_STATUS_CURRENT_CWD_WRAP" "$HERMES_TUI_STATUS_CURRENT_PATCH_CWD_WRAP"
            ;;
        revert)
            replace_hermes_tui_exact_line "$app_file" "$HERMES_TUI_STATUS_PATCH_CWD_COMMENT_1" "$HERMES_TUI_STATUS_UPSTREAM_CWD_COMMENT_1"
            replace_hermes_tui_exact_line "$app_file" "$HERMES_TUI_STATUS_PATCH_CWD_COMMENT_2" "$HERMES_TUI_STATUS_UPSTREAM_CWD_COMMENT_2"
            replace_hermes_tui_exact_line "$app_file" "$HERMES_TUI_STATUS_PATCH_CWD_COMMENT_3" "$HERMES_TUI_STATUS_UPSTREAM_CWD_COMMENT_3"
            replace_hermes_tui_exact_line "$app_file" "$HERMES_TUI_STATUS_PATCH_CWD_LABEL" "$HERMES_TUI_STATUS_UPSTREAM_CWD_LABEL"
            replace_hermes_tui_exact_line "$app_file" "$HERMES_TUI_STATUS_CURRENT_PATCH_CWD_LABEL" "$HERMES_TUI_STATUS_CURRENT_CWD_LABEL"
            replace_hermes_tui_exact_line "$chrome_file" "$HERMES_TUI_STATUS_PATCH_CWD_WRAP" "$HERMES_TUI_STATUS_UPSTREAM_CWD_WRAP"
            replace_hermes_tui_exact_line "$chrome_file" "$HERMES_TUI_STATUS_CURRENT_PATCH_CWD_WRAP" "$HERMES_TUI_STATUS_CURRENT_CWD_WRAP"
            ;;
        *)
            return 1
            ;;
    esac
}

tui_status_voice_ready() {
    local status_file="$INSTALL_DIR/$HERMES_TUI_STATUS_FILE"
    [ -f "$status_file" ] || return 1
    grep -Fqx "$HERMES_TUI_STATUS_PATCH_VOICE_LABEL" "$status_file" \
        || grep -Fqx "$HERMES_TUI_STATUS_CURRENT_PATCH_VOICE_TAIL" "$status_file"
}

tui_status_cwd_ready() {
    local app_file="$INSTALL_DIR/$HERMES_TUI_STATUS_FILE"
    local chrome_file="$INSTALL_DIR/$HERMES_TUI_STATUS_CHROME_FILE"
    [ -f "$app_file" ] || return 1
    [ -f "$chrome_file" ] || return 1
    { grep -Fqx "$HERMES_TUI_STATUS_PATCH_CWD_LABEL" "$app_file" \
        || grep -Fqx "$HERMES_TUI_STATUS_CURRENT_PATCH_CWD_LABEL" "$app_file"; } || return 1
    { grep -Fqx "$HERMES_TUI_STATUS_PATCH_CWD_WRAP" "$chrome_file" \
        || grep -Fqx "$HERMES_TUI_STATUS_CURRENT_PATCH_CWD_WRAP" "$chrome_file"; }
}

tui_status_ready() {
    tui_status_voice_ready || return 1
    tui_status_cwd_ready || return 1
}

tui_status_layout_known() {
    local app_file="$INSTALL_DIR/$HERMES_TUI_STATUS_FILE"
    local chrome_file="$INSTALL_DIR/$HERMES_TUI_STATUS_CHROME_FILE"
    [ -f "$app_file" ] && [ -f "$chrome_file" ] || return 1
    if ! grep -Fqx "$HERMES_TUI_STATUS_UPSTREAM_VOICE_LABEL" "$app_file" \
        && ! grep -Fqx "$HERMES_TUI_STATUS_LEGACY_PATCH_VOICE_LABEL" "$app_file" \
        && ! grep -Fqx "$HERMES_TUI_STATUS_PATCH_VOICE_LABEL" "$app_file" \
        && ! grep -Fqx "$HERMES_TUI_STATUS_CURRENT_VOICE_TAIL" "$app_file" \
        && ! grep -Fqx "$HERMES_TUI_STATUS_CURRENT_PATCH_VOICE_TAIL" "$app_file"; then
        return 1
    fi
    if ! tui_line_is_known "$app_file" "$HERMES_TUI_STATUS_UPSTREAM_CWD_LABEL" "$HERMES_TUI_STATUS_PATCH_CWD_LABEL" \
        && ! tui_line_is_known "$app_file" "$HERMES_TUI_STATUS_CURRENT_CWD_LABEL" "$HERMES_TUI_STATUS_CURRENT_PATCH_CWD_LABEL"; then
        return 1
    fi
    tui_line_is_known "$chrome_file" "$HERMES_TUI_STATUS_UPSTREAM_CWD_WRAP" "$HERMES_TUI_STATUS_PATCH_CWD_WRAP" \
        || tui_line_is_known "$chrome_file" "$HERMES_TUI_STATUS_CURRENT_CWD_WRAP" "$HERMES_TUI_STATUS_CURRENT_PATCH_CWD_WRAP"
}

ensure_hermes_tui_status_patch() {
    local status_file="$INSTALL_DIR/$HERMES_TUI_STATUS_FILE"
    [ -f "$status_file" ] || return 0
    tui_status_ready && return 0
    if ! tui_status_layout_known; then
        eecho "Warning: Hermes TUI status bar has an unknown layout; leaving it unchanged."
        return 0
    fi

    replace_hermes_tui_status_voice_line apply
    replace_hermes_tui_status_cwd_lines apply
    if tui_status_ready; then
        vecho "Hermes TUI status bar patched for voice density and wider cwd paths"
    else
        eecho "Warning: Hermes TUI status bar patch could not be applied; upstream UI may have changed."
    fi
}

remove_hermes_tui_status_patch() {
    replace_hermes_tui_status_cwd_lines revert
    replace_hermes_tui_status_voice_line revert
}

emit_hermes_tui_git_branch_upstream_block() {
    cat <<'EOF'
const resolveBranch = async (cwd: string): Promise<null | string> => {
  try {
    const { stdout } = await pexec('git', ['-C', cwd, 'rev-parse', '--abbrev-ref', 'HEAD'], { timeout: TIMEOUT_MS })
    const b = stdout.trim()

    return !b || b === 'HEAD' ? null : b
  } catch {
    return null
  }
}
EOF
}

emit_hermes_tui_git_branch_patch_block() {
    cat <<'EOF'
const firstLine = (value: string) => value.split(/\r?\n/, 1)[0]?.trim() ?? ''

const resolveGitBranch = async (cwd: string): Promise<null | string> => {
  try {
    const { stdout } = await pexec('git', ['-C', cwd, 'branch', '--show-current'], { timeout: TIMEOUT_MS })
    const b = firstLine(stdout)

    if (b) {
      return b
    }
  } catch {}

  try {
    const { stdout } = await pexec('git', ['-C', cwd, 'rev-parse', '--abbrev-ref', 'HEAD'], { timeout: TIMEOUT_MS })
    const b = firstLine(stdout)

    if (b && b !== 'HEAD') {
      return b
    }
  } catch {}

  return null
}

const resolveJjWorkspace = async (cwd: string): Promise<null | string> => {
  try {
    const { stdout: rootStdout } = await pexec('jj', ['--ignore-working-copy', 'workspace', 'root'], {
      cwd,
      timeout: TIMEOUT_MS
    })
    const root = firstLine(rootStdout)

    if (!root) {
      return null
    }

    const { stdout: listStdout } = await pexec(
      'jj',
      ['--ignore-working-copy', 'workspace', 'list', '--template', 'name ++ "\\t" ++ root ++ "\\n"'],
      { cwd, timeout: TIMEOUT_MS }
    )

    for (const line of listStdout.split(/\r?\n/)) {
      const [name, workspaceRoot] = line.split('\t')

      if (name && workspaceRoot === root) {
        return name.trim() || null
      }
    }

    return null
  } catch {
    return null
  }
}

const resolveJjBookmark = async (cwd: string): Promise<null | string> => {
  try {
    const { stdout } = await pexec(
      'jj',
      [
        '--ignore-working-copy',
        'log',
        '-r',
        'latest(bookmarks() & ancestors(@))',
        '--no-graph',
        '--template',
        'bookmarks.join(" ")'
      ],
      { cwd, timeout: TIMEOUT_MS }
    )
    const b = firstLine(stdout).split(/\s+/).filter(Boolean)[0] ?? ''

    return b || null
  } catch {
    return null
  }
}

const resolveJjStatus = async (cwd: string): Promise<null | string> => {
  const [workspace, bookmark] = await Promise.all([resolveJjWorkspace(cwd), resolveJjBookmark(cwd)])

  if (workspace && bookmark) {
    return `${workspace}:${bookmark}`
  }

  return workspace ?? bookmark
}

const resolveBranch = async (cwd: string): Promise<null | string> =>
  (await resolveJjStatus(cwd)) ?? (await resolveGitBranch(cwd))
EOF
}

replace_hermes_tui_git_branch_patch() {
    local mode="$1"
    local branch_file="$INSTALL_DIR/$HERMES_TUI_GIT_BRANCH_FILE"
    [ -f "$branch_file" ] || return 0

    local upstream_start_line patch_start_prefix patch_end_line legacy_patch_end_line block_file tmp awk_status
    upstream_start_line="const resolveBranch = async (cwd: string): Promise<null | string> => {"
    patch_start_prefix="const firstLine = (value: string) => value.split("
    patch_end_line="  (await resolveJjStatus(cwd)) ?? (await resolveGitBranch(cwd))"
    legacy_patch_end_line="  (await resolveGitBranch(cwd)) ?? (await resolveJjBookmark(cwd))"

    block_file="$(mktemp "${branch_file}.block.XXXXXX")" || return 1
    case "$mode" in
        apply)
            emit_hermes_tui_git_branch_patch_block > "$block_file"
            ;;
        revert)
            emit_hermes_tui_git_branch_upstream_block > "$block_file"
            ;;
        *)
            rm -f "$block_file"
            return 1
            ;;
    esac

    tmp="$(mktemp "${branch_file}.tmp.XXXXXX")" || {
        rm -f "$block_file"
        return 1
    }
    if awk \
        -v mode="$mode" \
        -v block_file="$block_file" \
        -v upstream_start_line="$upstream_start_line" \
        -v patch_start_prefix="$patch_start_prefix" \
        -v patch_end_line="$patch_end_line" \
        -v legacy_patch_end_line="$legacy_patch_end_line" '
        function print_block( line) {
            while ((getline line < block_file) > 0) print line
            close(block_file)
        }
        function flush_original( i) {
            for (i = 1; i <= buf_count; i++) print buf[i]
            buf_count = 0
        }
        function count_delta(line, open_count, close_count) {
            open_count = gsub(/\{/, "{", line)
            close_count = gsub(/\}/, "}", line)
            return open_count - close_count
        }
        mode == "apply" && candidate == "" && $0 == upstream_start_line {
            candidate = "apply"
            depth = count_delta($0)
            buf[++buf_count] = $0
            next
        }
        mode == "revert" && candidate == "" && index($0, patch_start_prefix) == 1 {
            candidate = "revert"
            buf[++buf_count] = $0
            next
        }
        candidate == "apply" {
            buf[++buf_count] = $0
            depth += count_delta($0)
            if (depth <= 0) {
                print_block()
                changed = 1
                candidate = ""
                buf_count = 0
            }
            next
        }
        candidate == "revert" {
            buf[++buf_count] = $0
            if ($0 == patch_end_line || $0 == legacy_patch_end_line) {
                print_block()
                changed = 1
                candidate = ""
                buf_count = 0
            }
            next
        }
        { print }
        END {
            if (candidate != "") flush_original()
            if (changed) exit 42
        }
    ' "$branch_file" > "$tmp"; then
        rm -f "$tmp" "$block_file"
        return 0
    else
        awk_status=$?
        rm -f "$block_file"
        if [ "$awk_status" -eq 42 ]; then
            if cmp -s "$tmp" "$branch_file"; then
                rm -f "$tmp"
            else
                mv "$tmp" "$branch_file"
            fi
            return 0
        fi
        rm -f "$tmp"
        return "$awk_status"
    fi
}

tui_git_branch_ready() {
    local branch_file="$INSTALL_DIR/$HERMES_TUI_GIT_BRANCH_FILE"
    [ -f "$branch_file" ] || return 1
    grep -Fqx "const resolveJjWorkspace = async (cwd: string): Promise<null | string> => {" "$branch_file" || return 1
    grep -Fq "name ++ \"\\\\t\" ++ root ++ \"\\\\n\"" "$branch_file" || return 1
    grep -Fq "latest(bookmarks() & ancestors(@))" "$branch_file" || return 1
    grep -Fqx "  (await resolveJjStatus(cwd)) ?? (await resolveGitBranch(cwd))" "$branch_file" || return 1
}

ensure_hermes_tui_git_branch_patch() {
    local branch_file="$INSTALL_DIR/$HERMES_TUI_GIT_BRANCH_FILE"
    [ -f "$branch_file" ] || return 0
    tui_git_branch_ready && return 0

    if ! git -C "$INSTALL_DIR" ls-files --error-unmatch "$HERMES_TUI_GIT_BRANCH_FILE" >/dev/null 2>&1 \
        || ! git -C "$INSTALL_DIR" diff --quiet -- "$HERMES_TUI_GIT_BRANCH_FILE"; then
        eecho "Warning: Hermes TUI branch source has local edits; leaving it unchanged."
        return 0
    fi

    replace_hermes_tui_git_branch_patch apply
    if tui_git_branch_ready; then
        vecho "Hermes TUI git branch status patched for jj workspace/bookmark fallback"
    else
        eecho "Warning: Hermes TUI git branch patch could not be applied; upstream UI may have changed."
    fi
}

remove_hermes_tui_git_branch_patch() {
    if tui_git_branch_ready; then
        replace_hermes_tui_git_branch_patch revert
    fi
}

tui_npm_deps_ready() {
    local workspace_root="$TUI_DIR"
    local hidden_lock lock_file

    if [ -f "$INSTALL_DIR/node_modules/@hermes/ink/package.json" ]; then
        workspace_root="$INSTALL_DIR"
    fi

    [ -f "$workspace_root/node_modules/@hermes/ink/package.json" ] || return 1
    hidden_lock="$workspace_root/node_modules/.package-lock.json"
    [ -f "$hidden_lock" ] || return 1

    lock_file="$workspace_root/package-lock.json"
    if [ -f "$lock_file" ] && [ "$lock_file" -nt "$hidden_lock" ]; then
        return 1
    fi
    return 0
}

tui_sources_newer_than() {
    local output_file="$1"
    local newer
    [ -f "$output_file" ] || return 0
    newer="$(find "$TUI_DIR/src" "$TUI_DIR/packages/hermes-ink/src" \
        -type f \( -name '*.ts' -o -name '*.tsx' \) \
        -newer "$output_file" -print -quit 2>/dev/null || true)"
    [ -n "$newer" ]
}

tui_build_fresh() {
    local entry="$TUI_DIR/dist/entry.js"
    local meta

    [ -f "$entry" ] || return 1
    tui_sources_newer_than "$entry" && return 1

    for meta in \
        "$TUI_DIR/package.json" \
        "$TUI_DIR/package-lock.json" \
        "$TUI_DIR/scripts/build.mjs" \
        "$TUI_DIR/tsconfig.json" \
        "$TUI_DIR/tsconfig.build.json" \
        "$TUI_DIR/packages/hermes-ink/package.json" \
        "$TUI_DIR/packages/hermes-ink/index.js" \
        "$TUI_DIR/packages/hermes-ink/text-input.js"; do
        [ -f "$meta" ] && [ "$meta" -nt "$entry" ] && return 1
    done

    return 0
}

tui_prebuild_ready() {
    [ "$HERMES_TUI_BY_DEFAULT" = "true" ] || return 0
    [ -d "$TUI_DIR" ] || return 1
    tui_build_fresh
}

ensure_hermes_tui_prebuilt() {
    local node_cmd
    [ "$HERMES_TUI_BY_DEFAULT" = "true" ] || return 0
    [ -d "$TUI_DIR" ] || return 0

    if ! NPM_CMD="$(resolve_npm_cmd)"; then
        eecho "Warning: node/npm not available; Hermes TUI will prepare itself on first launch."
        return 0
    fi
    node_cmd="$(resolve_node_cmd || true)"
    if [ -z "$node_cmd" ]; then
        eecho "Warning: node/npm not available; Hermes TUI will prepare itself on first launch."
        return 0
    fi
    export PATH="$(dirname "$node_cmd"):$PATH"

    if ! tui_npm_deps_ready; then
        if ! require_trust_for_remote_download "npm packages for Hermes TUI"; then
            eecho "Warning: skipping Hermes TUI prebuild because npm dependency install is not trusted yet."
            return 0
        fi
        eecho "Installing Hermes TUI node dependencies for fast startup..."
        (
            cd "$INSTALL_DIR" || exit 1
            env CI=1 "$NPM_CMD" ci --workspace ui-tui --no-fund --no-audit --progress=false
        ) || return $?
    fi

    if ! tui_build_fresh; then
        eecho "Prebuilding Hermes TUI for fast startup..."
        (
            cd "$TUI_DIR" || exit 1
            run_quiet "$NPM_CMD" run build
        ) || return $?
    fi
}
