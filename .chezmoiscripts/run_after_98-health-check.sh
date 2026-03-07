#!/usr/bin/env bash
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

# Colors (if terminal supports them)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# Counters for summary
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# Check function - pass/fail with message
check_pass() {
    vecho "${GREEN}[PASS]${NC} $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

check_warn() {
    vecho "${YELLOW}[WARN]${NC} $1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

check_fail() {
    eecho "${RED}[FAIL]${NC} $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

CHEZMOI_SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path 2>/dev/null || true)}"
if [ -z "$CHEZMOI_SOURCE_DIR" ]; then
    CHEZMOI_SOURCE_DIR="$HOME/.local/share/chezmoi"
fi
CHEZMOI_VERSION_FILE="$CHEZMOI_SOURCE_DIR/.chezmoiversion.toml"

get_pinned_version() {
    local key="$1"
    if [ ! -f "$CHEZMOI_VERSION_FILE" ]; then
        return 1
    fi
    sed -n "s/^${key} = \"\\([^\"]*\\)\"/\\1/p" "$CHEZMOI_VERSION_FILE" | head -1
}

vecho ""
vecho "=== Environment Health Check ==="
vecho ""

# 1. Shell configuration
vecho "--- Shell Configuration ---"

if [ -f "$HOME/.zshrc" ]; then
    check_pass "$HOME/.zshrc exists"
else
    check_fail "$HOME/.zshrc missing"
fi

if [ -f "$HOME/.zshenv" ]; then
    check_pass "$HOME/.zshenv exists"
else
    check_warn "$HOME/.zshenv missing (optional)"
fi

if [ -d "$HOME/.oh-my-zsh" ]; then
    check_pass "Oh My Zsh installed"
else
    check_fail "Oh My Zsh not installed"
fi

# Check ZSH plugins
for plugin in zsh-syntax-highlighting zsh-autosuggestions; do
    if [ -d "$HOME/.oh-my-zsh/custom/plugins/$plugin" ]; then
        check_pass "ZSH plugin: $plugin"
    else
        check_warn "ZSH plugin missing: $plugin"
    fi
done

# 2. Essential tools
vecho ""
vecho "--- Essential Tools ---"

for tool in zsh git curl; do
    if is_installed "$tool"; then
        check_pass "$tool: $(command -v $tool)"
    else
        check_fail "$tool not found"
    fi
done

vecho ""
vecho "--- Chezmoi Helper Commands ---"

if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    check_pass "~/.local/bin present in PATH"
else
    check_warn "~/.local/bin missing from PATH (managed cz* commands may be unavailable in this shell)"
fi

for tool in czu czuf czl czb czvc chezmoi-bump chezmoi-check-versions; do
    if is_installed "$tool"; then
        check_pass "$tool: $(command -v "$tool")"
    else
        check_fail "$tool not found (expected managed command in ~/.local/bin)"
    fi
done

# 3. Development tools (installed by setup scripts)
vecho ""
vecho "--- Development Tools ---"

# Make NVM-managed Node tools visible in non-interactive apply runs.
NVM_NODE_BIN=""
if [ -f "$HOME/.nvm/nvm.sh" ]; then
    # shellcheck disable=SC1090
    . "$HOME/.nvm/nvm.sh"
    if command -v nvm >/dev/null 2>&1; then
        NVM_NODE_PATH="$(nvm which default 2>/dev/null || true)"
        if [ -n "$NVM_NODE_PATH" ] && [ -x "$NVM_NODE_PATH" ]; then
            NVM_NODE_BIN="$(dirname "$NVM_NODE_PATH")"
            export PATH="$NVM_NODE_BIN:$PATH"
            hash -r 2>/dev/null || true
        fi
    fi
fi

# fzf
if is_installed fzf; then
    FZF_VERSION=$(fzf --version 2>/dev/null | awk '{print $1}' || echo "unknown")
    FZF_PINNED="$(get_pinned_version "fzf" || true)"
    if [ -n "$FZF_PINNED" ] && [ "$FZF_VERSION" != "$FZF_PINNED" ]; then
        check_warn "fzf: $FZF_VERSION (pinned: $FZF_PINNED)"
    else
        check_pass "fzf: $FZF_VERSION"
    fi
else
    check_warn "fzf not installed"
fi

# bat / batcat
if is_installed bat; then
    BAT_VERSION=$(bat --version 2>/dev/null | awk '{print $2}' || echo "unknown")
    check_pass "bat: $BAT_VERSION"
elif is_installed batcat; then
    BATCAT_VERSION=$(batcat --version 2>/dev/null | awk '{print $2}' || echo "unknown")
    check_pass "batcat: $BATCAT_VERSION"
else
    check_warn "bat/batcat not installed"
fi

# delta
if is_installed delta; then
    DELTA_VERSION=$(delta --version 2>/dev/null | awk '{print $2}' || echo "unknown")
    check_pass "delta: $DELTA_VERSION"
else
    check_warn "delta not installed"
fi

# eza / exa
if is_installed eza; then
    EZA_VERSION=$(eza --version 2>/dev/null | head -1 || echo "unknown")
    check_pass "eza: $EZA_VERSION"
elif is_installed exa; then
    EXA_VERSION=$(exa --version 2>/dev/null | head -1 || echo "unknown")
    check_pass "exa: $EXA_VERSION"
else
    check_warn "eza/exa not installed"
fi

# Node.js / NVM
if [ -d "$HOME/.nvm" ]; then
    check_pass "NVM installed"
    if is_installed node; then
        NODE_VERSION=$(node -v 2>/dev/null || echo "unknown")
        check_pass "Node.js: $NODE_VERSION"
    else
        check_warn "Node.js not available from NVM default alias"
    fi
else
    check_warn "NVM not installed"
fi

# uv (Python)
if is_installed uv; then
    UV_VERSION=$(uv --version 2>/dev/null | awk '{print $2}' || echo "unknown")
    UV_PINNED="$(get_pinned_version "uv" || true)"
    if [ -n "$UV_PINNED" ] && [ "$UV_VERSION" != "$UV_PINNED" ]; then
        check_warn "uv: $UV_VERSION (pinned: $UV_PINNED)"
    else
        check_pass "uv: $UV_VERSION"
    fi
else
    check_warn "uv not installed"
fi

# Jujutsu (jj)
if is_installed jj; then
    JJ_VERSION=$(jj version 2>/dev/null | awk '{print $2}' || echo "unknown")
    JJ_VERSION_CLEAN="$(printf '%s\n' "$JJ_VERSION" | cut -d- -f1)"
    JJ_PINNED="$(get_pinned_version "jj" || true)"
    JJ_PINNED_CLEAN="${JJ_PINNED#v}"
    if [ -n "$JJ_PINNED_CLEAN" ] && [ "$JJ_VERSION_CLEAN" != "$JJ_PINNED_CLEAN" ]; then
        check_warn "jj: $JJ_VERSION (pinned: $JJ_PINNED)"
    else
        check_pass "jj: $JJ_VERSION"
    fi
else
    check_warn "jj not installed"
fi

# Claude Code
if is_installed claude; then
    check_pass "Claude Code installed"
else
    check_warn "Claude Code not installed"
fi

# Codex CLI
if is_installed codex; then
    CODEX_VERSION="$(codex --version 2>/dev/null | awk '{print $NF}' || echo "unknown")"
    CODEX_PINNED="$(get_pinned_version "codex" || true)"
    CODEX_PINNED_CLEAN="${CODEX_PINNED#rust-v}"
    if [ -n "$CODEX_PINNED_CLEAN" ] && [ "$CODEX_VERSION" != "$CODEX_PINNED_CLEAN" ]; then
        check_warn "Codex CLI: $CODEX_VERSION (pinned: $CODEX_PINNED)"
    else
        check_pass "Codex CLI: $CODEX_VERSION"
    fi
else
    check_warn "Codex CLI not installed"
fi

# Bun
if is_installed bun; then
    BUN_VERSION=$(bun --version 2>/dev/null || echo "unknown")
    BUN_PINNED="$(get_pinned_version "bun" || true)"
    BUN_PINNED_CLEAN="${BUN_PINNED#bun-v}"
    if [ -n "$BUN_PINNED_CLEAN" ] && [ "$BUN_VERSION" != "$BUN_PINNED_CLEAN" ]; then
        check_warn "bun: $BUN_VERSION (pinned: $BUN_PINNED)"
    else
        check_pass "bun: $BUN_VERSION"
    fi
else
    check_warn "bun not installed"
fi

# Tailscale
if is_installed tailscale; then
    TAILSCALE_VERSION="$(tailscale version 2>/dev/null | awk 'NR==1{print $1}' || echo "unknown")"
    TAILSCALE_PINNED="$(get_pinned_version "tailscale" || true)"
    if [ -n "$TAILSCALE_PINNED" ] && [ "$TAILSCALE_VERSION" != "$TAILSCALE_PINNED" ]; then
        check_warn "tailscale: $TAILSCALE_VERSION (pinned: $TAILSCALE_PINNED)"
    else
        check_pass "tailscale: $TAILSCALE_VERSION"
    fi
else
    check_warn "tailscale not installed"
fi

# pnpm
if is_installed pnpm; then
    PNPM_VERSION=$(pnpm --version 2>/dev/null || echo "unknown")
    check_pass "pnpm: $PNPM_VERSION"
else
    check_warn "pnpm not installed"
fi

# yarn
if is_installed yarn; then
    YARN_VERSION=$(yarn --version 2>/dev/null || echo "unknown")
    check_pass "yarn: $YARN_VERSION"
else
    check_warn "yarn not installed"
fi

# Tmux
if is_installed tmux; then
    TMUX_VERSION=$(tmux -V 2>/dev/null | awk '{print $2}' || echo "unknown")
    check_pass "tmux: $TMUX_VERSION"

    # Check TPM (Tmux Plugin Manager)
    if [ -d "$HOME/.tmux/plugins/tpm" ]; then
        check_pass "TPM (Tmux Plugin Manager) installed"
    else
        check_warn "TPM not installed"
    fi
else
    check_warn "tmux not installed"
fi

# 4. Configuration files
vecho ""
vecho "--- Configuration Files ---"

if [ -f "$HOME/.tmux.conf" ]; then
    check_pass "$HOME/.tmux.conf exists"
else
    check_warn "$HOME/.tmux.conf missing"
fi

if [ -d "$HOME/.config/shell" ]; then
    SHELL_CONFIGS=$(find "$HOME/.config/shell" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$SHELL_CONFIGS" -gt 0 ]; then
        check_pass "Shell configs: $SHELL_CONFIGS files in ~/.config/shell/"
    else
        check_warn "No shell configs in ~/.config/shell/"
    fi
else
    check_warn "$HOME/.config/shell/ directory missing"
fi

# 5. State tracking
vecho ""
vecho "--- State Tracking ---"

if [ -d "$STATE_DIR" ]; then
    STATE_COUNT=$(find "$STATE_DIR" -name "*.done" 2>/dev/null | wc -l | tr -d ' ')
    check_pass "State directory: $STATE_COUNT tracked states"
else
    check_warn "State directory not initialized"
fi

# 6. Bootstrap security flags (if bootstrap-vps.sh was used)
vecho ""
vecho "--- Bootstrap Security Defaults ---"

BOOTSTRAP_FLAGS_FILE="$HOME/.config/bootstrap/security-flags.env"
if [ -f "$BOOTSTRAP_FLAGS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$BOOTSTRAP_FLAGS_FILE"

    if [ "${ALLOW_PASSWORDLESS_SUDO:-0}" = "1" ]; then
        check_warn "Bootstrap used ALLOW_PASSWORDLESS_SUDO=1"
    else
        check_pass "Passwordless sudo remains disabled by default"
    fi

    if [ "${COPY_ROOT_AUTH_KEYS:-0}" = "1" ]; then
        check_warn "Bootstrap used COPY_ROOT_AUTH_KEYS=1"
    else
        check_pass "Root authorized_keys was not copied by default"
    fi

    if [ "${TRUST_ON_FIRST_USE_INSTALLERS:-0}" = "1" ]; then
        check_warn "Bootstrap allowed remote installer scripts (TOFU mode)"
    else
        check_pass "Remote installer scripts require explicit trust"
    fi
else
    if [[ "$OSTYPE" == "darwin"* ]]; then
        check_pass "Bootstrap security flag file not required on macOS"
    elif [ "${CHEZMOI_ROLE:-workstation}" != "server" ]; then
        check_pass "Bootstrap security flag file not required for non-server role"
    else
        check_warn "Bootstrap security flag file not found (bootstrap-vps.sh may not have been used)"
    fi
fi

# Summary
TOTAL=$((PASS_COUNT + WARN_COUNT + FAIL_COUNT))

if [ "$FAIL_COUNT" -gt 0 ]; then
    vecho ""
    vecho "=== Health Check Summary ==="
    vecho "Passed: $PASS_COUNT / $TOTAL"
    if [ "$WARN_COUNT" -gt 0 ]; then
        vecho "Warnings: $WARN_COUNT"
    fi
    eecho "Health check: $FAIL_COUNT failure(s) detected. Run 'VERBOSE=true chezmoi apply' for details."
else
    vecho ""
    vecho "=== Health Check Summary ==="
    vecho "Passed: $PASS_COUNT / $TOTAL"
    if [ "$WARN_COUNT" -gt 0 ]; then
        vecho "Warnings: $WARN_COUNT"
    fi
    vecho "All health checks passed."
fi

vecho ""
