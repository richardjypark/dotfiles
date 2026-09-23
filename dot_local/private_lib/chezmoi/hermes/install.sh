hermes_current_ref() {
    [ -d "$INSTALL_DIR/.git" ] || return 1
    git -C "$INSTALL_DIR" rev-parse HEAD 2>/dev/null
}

hermes_ready() {
    state_exists "$HERMES_ENV_STATE" || return 1
    [ "$(hermes_current_ref 2>/dev/null || true)" = "$HERMES_REF" ] || return 1
    [ -x "$HERMES_BIN" ] || return 1
    HERMES_HOME="$HERMES_HOME_DIR" "$HERMES_BIN" --version >/dev/null 2>&1
}

repair_hermes_npm_lock_metadata() {
    # Older setup used npm install, which removed esbuild peer metadata.
    # Recover only that exact rewrite; staged edits and other changes stay put.
    [ "$(git -C "$INSTALL_DIR" status --porcelain)" = ' M package-lock.json' ] || return 0
    [ -x "$VENV_DIR/bin/python" ] || return 0
    "$VENV_DIR/bin/python" "$HERMES_LIB_DIR/lock_metadata.py" "$INSTALL_DIR" "$STATE_DIR"
}

checkout_hermes_ref() {
    if ! command -v git >/dev/null 2>&1; then
        eecho "Error: git is required before Hermes Agent setup. Install git, then rerun chezmoi apply."
        return 1
    fi
    if ! require_trust_for_remote_download "github.com/NousResearch/hermes-agent git checkout"; then
        return 1
    fi

    if [ -e "$INSTALL_DIR" ] && [ ! -d "$INSTALL_DIR/.git" ]; then
        eecho "Error: $INSTALL_DIR exists but is not a git checkout. Move it aside and rerun chezmoi apply."
        return 1
    fi

    mkdir -p "$(dirname "$INSTALL_DIR")"
    if [ -d "$INSTALL_DIR/.git" ]; then
        remove_hermes_tui_diff_color_patch
        remove_hermes_tui_status_patch
        remove_hermes_tui_git_branch_patch
        repair_hermes_npm_lock_metadata
        local checkout_status
        checkout_status="$(git -C "$INSTALL_DIR" status --porcelain)" || return 1
        if [ -n "$checkout_status" ]; then
            eecho "Error: local changes exist in $INSTALL_DIR; refusing to overwrite them."
            printf '%s\n' "$checkout_status" >&2
            return 1
        fi
        run_quiet git -C "$INSTALL_DIR" remote set-url origin "$HERMES_REPO_URL" || return $?
        run_quiet git -C "$INSTALL_DIR" fetch --depth 1 origin "$HERMES_BRANCH" || return $?
    else
        eecho "Cloning Hermes Agent $HERMES_VERSION for this host..."
        run_quiet git clone --depth 1 --branch "$HERMES_BRANCH" "$HERMES_REPO_URL" "$INSTALL_DIR" || return $?
    fi

    if ! git -C "$INSTALL_DIR" cat-file -e "$HERMES_REF^{commit}" 2>/dev/null; then
        run_quiet git -C "$INSTALL_DIR" fetch --depth 1 origin "$HERMES_REF" || return $?
    fi
    run_quiet git -C "$INSTALL_DIR" checkout --detach "$HERMES_REF"
}

sync_hermes_environment() {
    if ! require_trust_for_remote_download "PyPI packages for Hermes Agent"; then
        return 1
    fi
    if ! command -v uv >/dev/null 2>&1; then
        eecho "Error: uv is required before Hermes Agent setup. Rerun chezmoi apply after uv setup completes."
        return 1
    fi

    local sync_args=(sync --locked --python "$PYTHON_VERSION" --no-dev)
    local extra
    for extra in "${HERMES_EXTRAS[@]}"; do
        sync_args+=(--extra "$extra")
    done

    eecho "Installing Hermes Agent lean VPS profile (${HERMES_EXTRAS_KEY})..."
    (
        cd "$INSTALL_DIR" || exit 1
        export UV_PROJECT_ENVIRONMENT="$VENV_DIR"
        export UV_LINK_MODE="copy"
        uv "${sync_args[@]}"
    ) || return $?
    mark_state "$HERMES_ENV_STATE"
}
