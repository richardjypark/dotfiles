launcher_ready() {
    [ -x "$LAUNCHER" ] || return 1
    grep -Fq "exec \"$HERMES_BIN\"" "$LAUNCHER" 2>/dev/null || return 1
    if [ "$HERMES_TUI_BY_DEFAULT" = "true" ]; then
        grep -Fq "HERMES_TUI=1" "$LAUNCHER" 2>/dev/null || return 1
        grep -Fq "HERMES_TUI_DIR" "$LAUNCHER" 2>/dev/null || return 1
    fi
    return 0
}

config_ready() {
    [ -d "$HERMES_HOME_DIR" ] && [ -f "$HERMES_HOME_DIR/config.yaml" ] && [ -f "$HERMES_HOME_DIR/SOUL.md" ]
}

run_hermes_cli() {
    env -u PYTHONPATH -u PYTHONHOME HERMES_HOME="$HERMES_HOME_DIR" "$HERMES_BIN" "$@"
}

ensure_public_hermes_preferences() {
    [ -x "$HERMES_BIN" ] || return 0
    [ -f "$HERMES_HOME_DIR/config.yaml" ] || return 0

    # This run_after script runs on every chezmoi apply. Keep public dotfiles
    # from tracking the full Hermes runtime config while still converging
    # stable, non-sensitive preferences from .chezmoidata.toml. API keys and
    # machine-local credentials remain in ~/.hermes/config.yaml or .env.
    run_quiet run_hermes_cli config set model.provider "$HERMES_MODEL_PROVIDER"
    run_quiet run_hermes_cli config set model.default "$HERMES_MODEL"
    run_quiet run_hermes_cli config set model.base_url "$HERMES_MODEL_BASE_URL"
    run_quiet run_hermes_cli config set model.api_key ""
    run_quiet run_hermes_cli config set model.api_mode ""
    run_quiet run_hermes_cli config set display.show_reasoning "$HERMES_SHOW_REASONING"
    run_quiet run_hermes_cli config set agent.reasoning_effort "$HERMES_REASONING_EFFORT"
    run_quiet run_hermes_cli config set agent.service_tier "$HERMES_SERVICE_TIER"
    run_quiet run_hermes_cli config set agent.max_turns "$HERMES_AGENT_MAX_TURNS"
    run_quiet run_hermes_cli config set goals.max_turns "$HERMES_GOALS_MAX_TURNS"
    run_quiet run_hermes_cli config set model.context_length "$HERMES_CONTEXT_LENGTH"
    # Empty delegation values are intentional. They clear stale overrides so
    # subagents inherit the active parent provider, model, and reasoning level.
    run_quiet run_hermes_cli config set delegation.provider "$HERMES_DELEGATION_PROVIDER"
    run_quiet run_hermes_cli config set delegation.model "$HERMES_DELEGATION_MODEL"
    run_quiet run_hermes_cli config set delegation.reasoning_effort "$HERMES_DELEGATION_REASONING_EFFORT"
}

ensure_hermes_shared_skills_external_dir() {
    [ -d "$SHARED_SKILLS_DIR" ] || return 0
    [ -x "$VENV_DIR/bin/python" ] || return 0
    [ -f "$HERMES_HOME_DIR/config.yaml" ] || return 0

    (
        export HERMES_CONFIG_PATH="$HERMES_HOME_DIR/config.yaml"
        # shellcheck disable=SC2088 # Preserve a portable tilde entry in Hermes config.
        export HERMES_SHARED_SKILLS_ENTRY="~/.agents/skills"
        run_quiet "$VENV_DIR/bin/python" "$HERMES_LIB_DIR/config.py"
    )
}

write_launcher() {
    mkdir -p "$HOME/.local/bin"
    cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash
unset PYTHONPATH
unset PYTHONHOME
export HERMES_HOME="$HERMES_HOME_DIR"
export HERMES_TUI_DIR="\${HERMES_TUI_DIR:-$TUI_DIR}"
if [ "$HERMES_TUI_BY_DEFAULT" = "true" ] && [ -z "\${HERMES_TUI+x}" ] && [ -t 0 ] && [ -t 1 ]; then
    export HERMES_TUI=1
fi
exec "$HERMES_BIN" "\$@"
EOF
    chmod 755 "$LAUNCHER"
}

seed_hermes_home() {
    mkdir -p "$HERMES_HOME_DIR"/{cron,sessions,logs,pairing,hooks,image_cache,audio_cache,memories,skills}

    if [ ! -f "$HERMES_HOME_DIR/config.yaml" ] && [ -f "$INSTALL_DIR/cli-config.yaml.example" ]; then
        cp "$INSTALL_DIR/cli-config.yaml.example" "$HERMES_HOME_DIR/config.yaml"
        chmod 600 "$HERMES_HOME_DIR/config.yaml"
    fi

    if [ ! -f "$HERMES_HOME_DIR/SOUL.md" ]; then
        cat > "$HERMES_HOME_DIR/SOUL.md" <<'SOUL_EOF'
# Hermes Agent Persona

<!--
Machine-local Hermes persona. Edit this file to customize the agent's tone.
This dotfiles setup does not manage Hermes API keys or .env files.
-->
SOUL_EOF
    fi

    if [ -x "$VENV_DIR/bin/python" ] && [ -f "$INSTALL_DIR/tools/skills_sync.py" ]; then
        (
            export HERMES_HOME="$HERMES_HOME_DIR"
            run_quiet "$VENV_DIR/bin/python" "$INSTALL_DIR/tools/skills_sync.py"
        ) || true
    fi
}
