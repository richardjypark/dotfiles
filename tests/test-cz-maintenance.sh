#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUMP_BIN="${SCRIPT_ROOT}/dot_local/bin/executable_chezmoi-bump"

PASS_COUNT=0
FAIL_COUNT=0
BUMP_BG_PID=""
TERM_EXIT_CODE="${TERM_EXIT_CODE:-143}"

log() {
    printf '%s\n' "$*"
}

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    log "[PASS] $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    log "[FAIL] $1"
    return 1
}

assert_true() {
    local condition="$1"
    local msg="$2"
    if eval "$condition"; then
        pass "$msg"
    else
        fail "$msg"
    fi
}

assert() {
    assert_true "$1" "$2"
}

assert_eq() {
    local got="$1"
    local expected="$2"
    local msg="$3"
    if [ "$got" = "$expected" ]; then
        pass "$msg"
        return 0
    fi
    fail "$msg (got=$got expected=$expected)"
}

assert_file_contains() {
    local file="$1"
    local expected="$2"
    local msg="$3"
    if [ -f "$file" ] && grep -Fq "$expected" "$file"; then
        pass "$msg"
        return 0
    fi
    fail "$msg"
}

assert_file_not_contains() {
    local file="$1"
    local expected="$2"
    local msg="$3"
    if [ -f "$file" ] && ! grep -Fq "$expected" "$file"; then
        pass "$msg"
        return 0
    fi
    fail "$msg"
}

toml_section_value() {
    local file="$1"
    local section="$2"
    local key="$3"

    awk -v header="[${section}]" -v wanted_key="$key" '
        $0 == header { in_section = 1; next }
        in_section && /^\[/ { exit }
        in_section && $1 == wanted_key && $2 == "=" {
            value = $3
            gsub(/^"|"$/, "", value)
            print value
            exit
        }
    ' "$file"
}

assert_toml_section_value() {
    local file="$1"
    local section="$2"
    local key="$3"
    local expected="$4"
    local msg="$5"
    local actual

    actual="$(toml_section_value "$file" "$section" "$key")"
    assert_eq "$actual" "$expected" "$msg"
}

assert_path_absent() {
    local path="$1"
    local msg="$2"
    if [ ! -e "$path" ]; then
        pass "$msg"
        return 0
    fi
    fail "$msg (path exists: $path)"
}

create_stubs() {
    local root="$1"
    local bin_dir="${root}/bin"

    mkdir -p "$bin_dir"

    cat >"${bin_dir}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

url=""
output_to=""
has_head=0

while [ $# -gt 0 ]; do
    case "$1" in
        -o)
            output_to="$2"
            shift 2
            ;;
        -o*)
            output_to="${1#-o}"
            shift
            ;;
        -*)
            case "$1" in
                -fsSLI|-I|*I*)
                    if printf '%s' "$1" | grep -q 'I'; then
                        has_head=1
                    fi
                    ;;
            esac
            shift
            ;;
        http://*|https://*)
            url="$1"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [ "$has_head" -eq 1 ]; then
    exit 0
fi

response='{}'
case "$url" in
    *"/repos/neovim/neovim/releases/latest")
        response="{\"tag_name\":\"${MOCK_NEOVIM_LATEST}\"}" ;;
    *"/repos/jj-vcs/jj/releases/latest")
        response="{\"tag_name\":\"${MOCK_JJ_LATEST}\"}" ;;
    *"/repos/nvm-sh/nvm/releases/latest")
        response="{\"tag_name\":\"${MOCK_NVM_LATEST}\"}" ;;
    *"/repos/junegunn/fzf/releases/latest")
        response="{\"tag_name\":\"${MOCK_FZF_LATEST}\"}" ;;
    *"/repos/zsh-users/zsh-syntax-highlighting/releases/latest")
        response="{\"tag_name\":\"${MOCK_ZSH_SYNTAX_HIGHLIGHTING_LATEST}\"}" ;;
    *"/repos/zsh-users/zsh-autosuggestions/releases/latest")
        response="{\"tag_name\":\"${MOCK_ZSH_AUTOSUGGESTIONS_LATEST}\"}" ;;
    *"/repos/openai/codex/releases?per_page=30")
        response="[{\"prerelease\":false,\"tag_name\":\"${MOCK_CODEX_LATEST}\"},{\"prerelease\":false,\"tag_name\":\"${MOCK_CODEX_PREVIOUS}\"}]" ;;
    *"/repos/astral-sh/uv/releases/latest")
        response="{\"tag_name\":\"${MOCK_UV_LATEST}\"}" ;;
    *"/repos/starship/starship/releases/latest")
        response="{\"tag_name\":\"${MOCK_STARSHIP_LATEST}\"}" ;;
    *"/repos/oven-sh/bun/releases/latest")
        response="{\"tag_name\":\"${MOCK_BUN_LATEST}\"}" ;;
    *"/repos/tailscale/tailscale/releases/latest")
        response="{\"tag_name\":\"${MOCK_TAILSCALE_LATEST}\"}" ;;
    *"/repos/twpayne/chezmoi/releases/latest")
        response="{\"tag_name\":\"${MOCK_CHEZMOI_LATEST}\"}" ;;
    *"/registry.npmjs.org/%40earendil-works%2Fpi-coding-agent")
        response="{\"dist-tags\":{\"latest\":\"${MOCK_PI_LATEST}\"},\"time\":{\"1.0.0\":\"2024-01-01T00:00:00.000Z\",\"${MOCK_PI_LATEST}\":\"2024-01-01T00:00:00.000Z\"}}" ;;
    *"/registry.npmjs.org/%40anthropic-ai%2Fclaude-code")
        response="{\"dist-tags\":{\"latest\":\"${MOCK_CLAUDE_LATEST}\"}}" ;;
    *"/repos/tailscale/tailscale/releases?per_page=10")
        response='[]' ;;
    *"/repos/tailscale/tailscale/releases?"*)
        response="[{\"prerelease\":false,\"tag_name\":\"${MOCK_TAILSCALE_LATEST}\"},{\"prerelease\":false,\"tag_name\":\"${MOCK_TAILSCALE_PREVIOUS}\"}]" ;;
    *)
        response='{}'
        ;;
esac

if [ -n "$output_to" ]; then
    printf '%s\n' "$response" >"$output_to"
else
    printf '%s\n' "$response"
fi
EOF
    chmod +x "${bin_dir}/curl"

    cat >"${bin_dir}/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

sleep_seconds="${PI_NPM_SLEEP:-0}"
behavior="${PI_NPM_BEHAVIOR:-ok}"

if [ "$sleep_seconds" -gt 0 ]; then
    sleep "$sleep_seconds"
fi

if [ "$behavior" = "fail" ]; then
    echo "npm failed" >&2
    exit 1
fi

if [ ! -f "$PWD/package.json" ]; then
    exit 0
fi

current_version="$(sed -n 's/.*"@earendil-works\/pi-coding-agent"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PWD/package.json" | head -1)"
if [ -z "$current_version" ]; then
    current_version="1.0.0"
fi

if [ "$behavior" = "wrong" ]; then
    current_version="1.0.0"
fi

cat > package-lock.json <<PKGLOCK_EOF
{
  "packages": {
    "": { "dependencies": { "@earendil-works/pi-coding-agent": "${current_version}" } },
    "node_modules/@earendil-works/pi-coding-agent": { "version": "${current_version}" }
  }
}
PKGLOCK_EOF

exit 0
EOF
    chmod +x "${bin_dir}/npm"
}

render_fixture() {
    local root="$1"
    local chezmoi_dir="${root}/.local/share/chezmoi"

    mkdir -p "$chezmoi_dir/dot_local/share/pi-cli" \
        "$chezmoi_dir/dot_local/share/pi-maintenance-agent" \
        "$chezmoi_dir/dot_pi/agent" \
        "$chezmoi_dir/dot_local/private_lib"

    cat >"${chezmoi_dir}/dot_local/private_lib/chezmoi-helpers.sh" <<'EOF'
#!/usr/bin/env bash
resolve_npm_cmd() { return 0; }
npm_require_minimum_lockfile_age() { return 0; }
EOF

    cat >"${chezmoi_dir}/.chezmoidata.toml" <<'EOF'
[pinned.neovim]
version = "1.0.0"

[pinned.jj]
version = "1.0.0"

[pinned.codex]
version = "rust-v1.0.0"

[pinned.uv]
version = "1.0.0"

[pinned.starship]
version = "v1.0.0"

[pinned.bun]
version = "bun-v1.0.0"

[pinned.tailscale]
version = "1.0.0"

[pinned.chezmoi]
version = "1.0.0"

[pinned.claude]
npm_version = "1.0.0"

[nvm]
version = "1.0.0"
EOF

    cat >"${chezmoi_dir}/.chezmoiversion.toml" <<'EOF'
[versions]
neovim = "1.0.0"
jj = "1.0.0"
codex = "rust-v1.0.0"
uv = "1.0.0"
starship = "v1.0.0"
bun = "bun-v1.0.0"
tailscale = "1.0.0"
fzf = "v1.0.0"
claude_code_npm = "1.0.0"
EOF

    cat >"${chezmoi_dir}/.chezmoiexternal.toml.tmpl" <<'EOF'
[".local/share/fzf"]
refreshPeriod = "168h"
files = ["--branch", "v1.0.0"]

[".local/share/zsh-syntax-highlighting"]
refreshPeriod = "168h"
url = "https://github.com/zsh-users/zsh-syntax-highlighting/archive/refs/tags/v1.0.0.tar.gz"

[".local/share/zsh-autosuggestions"]
refreshPeriod = "168h"
url = "https://github.com/zsh-users/zsh-autosuggestions/archive/refs/tags/v1.0.0.tar.gz"
EOF

    cat >"${chezmoi_dir}/dot_local/share/pi-cli/package.json" <<'EOF'
{
  "name": "pi-cli",
  "dependencies": {
    "@earendil-works/pi-coding-agent": "1.0.0"
  }
}
EOF

    cat >"${chezmoi_dir}/dot_local/share/pi-maintenance-agent/package.json" <<'EOF'
{
  "name": "pi-maintenance-agent",
  "dependencies": {
    "@earendil-works/pi-coding-agent": "1.0.0"
  }
}
EOF

    cat >"${chezmoi_dir}/dot_local/share/pi-cli/package-lock.json" <<'EOF'
{
  "packages": {
    "": { "dependencies": { "@earendil-works/pi-coding-agent": "1.0.0" } },
    "node_modules/@earendil-works/pi-coding-agent": { "version": "1.0.0" }
  }
}
EOF

    cp "${chezmoi_dir}/dot_local/share/pi-cli/package-lock.json" \
        "${chezmoi_dir}/dot_local/share/pi-maintenance-agent/package-lock.json"

    cat >"${chezmoi_dir}/dot_pi/agent/settings.json" <<'EOF'
{
  "lastChangelogVersion": "1.0.0",
  "lastMaintenanceRun": "none"
}
EOF
}

run_bump() {
    local fixture_dir="$1"
    local log_file="$2"
    shift 2

    HOME="${fixture_dir}" \
        CHEZMOI_DIR="${fixture_dir}/.local/share/chezmoi" \
        XDG_STATE_HOME="${fixture_dir}/.local/state" \
        PATH="${fixture_dir}/bin:$PATH" \
        MOCK_NEOVIM_LATEST="${MOCK_NEOVIM_LATEST:-1.0.0}" \
        MOCK_JJ_LATEST="${MOCK_JJ_LATEST:-1.0.0}" \
        MOCK_NVM_LATEST="${MOCK_NVM_LATEST:-v1.0.0}" \
        MOCK_FZF_LATEST="${MOCK_FZF_LATEST:-1.0.0}" \
        MOCK_ZSH_SYNTAX_HIGHLIGHTING_LATEST="${MOCK_ZSH_SYNTAX_HIGHLIGHTING_LATEST:-v1.0.0}" \
        MOCK_ZSH_AUTOSUGGESTIONS_LATEST="${MOCK_ZSH_AUTOSUGGESTIONS_LATEST:-v1.0.0}" \
        MOCK_CODEX_LATEST="${MOCK_CODEX_LATEST:-rust-v1.0.0}" \
        MOCK_CODEX_PREVIOUS="${MOCK_CODEX_PREVIOUS:-rust-v0.9.0}" \
        MOCK_UV_LATEST="${MOCK_UV_LATEST:-1.0.0}" \
        MOCK_STARSHIP_LATEST="${MOCK_STARSHIP_LATEST:-v1.0.0}" \
        MOCK_BUN_LATEST="${MOCK_BUN_LATEST:-bun-v1.0.0}" \
        MOCK_TAILSCALE_LATEST="${MOCK_TAILSCALE_LATEST:-1.0.0}" \
        MOCK_TAILSCALE_PREVIOUS="${MOCK_TAILSCALE_PREVIOUS:-0.9.0}" \
        MOCK_CHEZMOI_LATEST="${MOCK_CHEZMOI_LATEST:-1.0.0}" \
        MOCK_CLAUDE_LATEST="${MOCK_CLAUDE_LATEST:-1.0.0}" \
        MOCK_PI_LATEST="${MOCK_PI_LATEST:-1.0.0}" \
        PI_NPM_BEHAVIOR="${PI_NPM_BEHAVIOR:-ok}" \
        PI_NPM_SLEEP="${PI_NPM_SLEEP:-0}" \
        bash "$BUMP_BIN" "$@" >"${log_file}" 2>&1
}

run_bump_with_env() {
    local fixture_dir="$1"
    local log_file="$2"
    shift 2

    HOME="${fixture_dir}" \
        CHEZMOI_DIR="${fixture_dir}/.local/share/chezmoi" \
        XDG_STATE_HOME="${fixture_dir}/.local/state" \
        PATH="${fixture_dir}/bin:$PATH" \
        MOCK_NEOVIM_LATEST="${MOCK_NEOVIM_LATEST:-1.0.0}" \
        MOCK_JJ_LATEST="${MOCK_JJ_LATEST:-1.0.0}" \
        MOCK_NVM_LATEST="${MOCK_NVM_LATEST:-v1.0.0}" \
        MOCK_FZF_LATEST="${MOCK_FZF_LATEST:-1.0.0}" \
        MOCK_ZSH_SYNTAX_HIGHLIGHTING_LATEST="${MOCK_ZSH_SYNTAX_HIGHLIGHTING_LATEST:-v1.0.0}" \
        MOCK_ZSH_AUTOSUGGESTIONS_LATEST="${MOCK_ZSH_AUTOSUGGESTIONS_LATEST:-v1.0.0}" \
        MOCK_CODEX_LATEST="${MOCK_CODEX_LATEST:-rust-v1.0.0}" \
        MOCK_CODEX_PREVIOUS="${MOCK_CODEX_PREVIOUS:-rust-v0.9.0}" \
        MOCK_UV_LATEST="${MOCK_UV_LATEST:-1.0.0}" \
        MOCK_STARSHIP_LATEST="${MOCK_STARSHIP_LATEST:-v1.0.0}" \
        MOCK_BUN_LATEST="${MOCK_BUN_LATEST:-bun-v1.0.0}" \
        MOCK_TAILSCALE_LATEST="${MOCK_TAILSCALE_LATEST:-1.0.0}" \
        MOCK_TAILSCALE_PREVIOUS="${MOCK_TAILSCALE_PREVIOUS:-0.9.0}" \
        MOCK_CHEZMOI_LATEST="${MOCK_CHEZMOI_LATEST:-1.0.0}" \
        MOCK_CLAUDE_LATEST="${MOCK_CLAUDE_LATEST:-1.0.0}" \
        MOCK_PI_LATEST="${MOCK_PI_LATEST:-1.0.0}" \
        PI_NPM_BEHAVIOR="${PI_NPM_BEHAVIOR:-ok}" \
        PI_NPM_SLEEP="${PI_NPM_SLEEP:-0}" \
        bash "$BUMP_BIN" "$@"
}

run_bump_bg() {
    local fixture_dir="$1"
    shift
    local log_file="$1"
    shift

    HOME="${fixture_dir}" \
        CHEZMOI_DIR="${fixture_dir}/.local/share/chezmoi" \
        XDG_STATE_HOME="${fixture_dir}/.local/state" \
        PATH="${fixture_dir}/bin:$PATH" \
        MOCK_NEOVIM_LATEST="${MOCK_NEOVIM_LATEST:-1.0.0}" \
        MOCK_JJ_LATEST="${MOCK_JJ_LATEST:-1.0.0}" \
        MOCK_NVM_LATEST="${MOCK_NVM_LATEST:-v1.0.0}" \
        MOCK_FZF_LATEST="${MOCK_FZF_LATEST:-1.0.0}" \
        MOCK_ZSH_SYNTAX_HIGHLIGHTING_LATEST="${MOCK_ZSH_SYNTAX_HIGHLIGHTING_LATEST:-v1.0.0}" \
        MOCK_ZSH_AUTOSUGGESTIONS_LATEST="${MOCK_ZSH_AUTOSUGGESTIONS_LATEST:-v1.0.0}" \
        MOCK_CODEX_LATEST="${MOCK_CODEX_LATEST:-rust-v1.0.0}" \
        MOCK_CODEX_PREVIOUS="${MOCK_CODEX_PREVIOUS:-rust-v0.9.0}" \
        MOCK_UV_LATEST="${MOCK_UV_LATEST:-1.0.0}" \
        MOCK_STARSHIP_LATEST="${MOCK_STARSHIP_LATEST:-v1.0.0}" \
        MOCK_BUN_LATEST="${MOCK_BUN_LATEST:-bun-v1.0.0}" \
        MOCK_TAILSCALE_LATEST="${MOCK_TAILSCALE_LATEST:-1.0.0}" \
        MOCK_TAILSCALE_PREVIOUS="${MOCK_TAILSCALE_PREVIOUS:-0.9.0}" \
        MOCK_CHEZMOI_LATEST="${MOCK_CHEZMOI_LATEST:-1.0.0}" \
        MOCK_CLAUDE_LATEST="${MOCK_CLAUDE_LATEST:-1.0.0}" \
        MOCK_PI_LATEST="${MOCK_PI_LATEST:-1.0.0}" \
        PI_NPM_BEHAVIOR="${PI_NPM_BEHAVIOR:-ok}" \
        PI_NPM_SLEEP="${PI_NPM_SLEEP:-0}" \
        bash "$BUMP_BIN" "$@" >"${log_file}" 2>&1 &
    BUMP_BG_PID=$!
}

wait_for_progress() {
    local fixture_dir="$1"
    local log_file="$2"
    local marker="$3"
    local timeout_seconds="${4:-5}"
    local data_file="${5:-}"
    local expected="${6:-}"

    local attempts=0
    local max_attempts=$((timeout_seconds * 10))
    while [ "$attempts" -lt "$max_attempts" ]; do
        if [ -n "$data_file" ] && [ -n "$expected" ] && [ -f "$data_file" ] && grep -Fq "$expected" "$data_file"; then
            return 0
        fi

        if [ -f "$log_file" ] && grep -Fq "$marker" "$log_file"; then
            return 0
        fi

        sleep 0.1
        attempts=$((attempts + 1))
    done

    return 1
}

test_atomic_rollback_on_inner_failure() {
    local fixture_dir log status
    local MOCK_NEOVIM_LATEST MOCK_PI_LATEST PI_NPM_BEHAVIOR PI_NPM_SLEEP
    fixture_dir="$(mktemp -d)"
    create_stubs "$fixture_dir"
    render_fixture "$fixture_dir"

    MOCK_NEOVIM_LATEST="2.0.0"
    MOCK_PI_LATEST="2.0.0"
    PI_NPM_BEHAVIOR="wrong"

    log="${fixture_dir}/run.log"
    if run_bump "$fixture_dir" "$log" --all --skip-sha; then
        status=0
    else
        status=$?
    fi

    if [ "$status" -ne 0 ]; then
        pass "--all should return non-zero on failed atomic run"
    else
        fail "--all should return non-zero on failed atomic run"
    fi
    assert_file_contains "$log" "Rolling back all dependency changes" "Outer rollback should be reported"
    assert_path_absent "${fixture_dir}/.local/state/chezmoi-maintenance/chezmoi-bump" "Outer lock removed on failure"
    assert_toml_section_value "${fixture_dir}/.local/share/chezmoi/.chezmoidata.toml" "pinned.neovim" "version" "1.0.0" "Neovim pin restored after failure"
    assert_toml_section_value "${fixture_dir}/.local/share/chezmoi/.chezmoiversion.toml" "versions" "neovim" "1.0.0" "Neovim version manifest restored after failure"
    assert_file_contains "${fixture_dir}/.local/share/chezmoi/dot_local/share/pi-cli/package.json" '"@earendil-works/pi-coding-agent": "1.0.0"' "Pi package version restored after failure"
    assert_file_contains "${fixture_dir}/.local/share/chezmoi/dot_pi/agent/settings.json" '"lastChangelogVersion": "1.0.0"' "Pi settings restored after failure"

    rm -rf "$fixture_dir"
}

test_atomic_success_multiple_targets() {
    local fixture_dir log status
    local MOCK_NEOVIM_LATEST MOCK_PI_LATEST PI_NPM_BEHAVIOR PI_NPM_SLEEP
    fixture_dir="$(mktemp -d)"
    create_stubs "$fixture_dir"
    render_fixture "$fixture_dir"

    MOCK_NEOVIM_LATEST="2.0.0"
    MOCK_PI_LATEST="2.0.0"
    PI_NPM_BEHAVIOR="ok"

    log="${fixture_dir}/run.log"
    if run_bump "$fixture_dir" "$log" --all --skip-sha; then
        status=0
    else
        status=$?
    fi

    assert_eq "$status" "0" "--all should succeed when all updated dependencies apply"
    assert_toml_section_value "${fixture_dir}/.local/share/chezmoi/.chezmoidata.toml" "pinned.neovim" "version" "v2.0.0" "Neovim pin updated"
    assert_toml_section_value "${fixture_dir}/.local/share/chezmoi/.chezmoiversion.toml" "versions" "neovim" "v2.0.0" "Neovim version manifest updated"
    assert_file_contains "${fixture_dir}/.local/share/chezmoi/dot_local/share/pi-cli/package.json" '"@earendil-works/pi-coding-agent": "2.0.0"' "Pi package updated"
    assert_file_contains "${fixture_dir}/.local/share/chezmoi/dot_pi/agent/settings.json" '"lastChangelogVersion": "2.0.0"' "Pi settings updated"

    rm -rf "$fixture_dir"
}

test_lock_contention_fails() {
    local fixture_dir log status
    local MOCK_NEOVIM_LATEST MOCK_PI_LATEST PI_NPM_BEHAVIOR PI_NPM_SLEEP
    fixture_dir="$(mktemp -d)"
    create_stubs "$fixture_dir"
    render_fixture "$fixture_dir"

    mkdir -p "${fixture_dir}/.local/state/chezmoi-maintenance/chezmoi-bump"
    cat >"${fixture_dir}/.local/state/chezmoi-maintenance/chezmoi-bump/meta" <<'EOF'
pid=9999999
host=test-host
command=chezmoi-bump --all
start_ts=2000-01-01T00:00:00Z
EOF

    MOCK_NEOVIM_LATEST="2.0.0"
    MOCK_PI_LATEST="2.0.0"

    log="${fixture_dir}/run.log"
    if run_bump "$fixture_dir" "$log" --all --skip-sha; then
        status=0
    else
        status=$?
    fi

    assert_eq "$status" "1" "--all with lock contention should fail"
    assert_file_contains "$log" "Another" "Lock contention reported"
    assert_file_contains "$log" "Refusing" "Lock contention should explain refusal"
    assert_file_contains "$log" "pid=9999999" "Lock contention reports recorded owner"
    assert_toml_section_value "${fixture_dir}/.local/share/chezmoi/.chezmoidata.toml" "pinned.neovim" "version" "1.0.0" "No pin change on lock contention"

    rm -rf "$fixture_dir"
}

test_signal_rolls_back() {
    local fixture_dir log pid status
    local MOCK_NEOVIM_LATEST MOCK_PI_LATEST PI_NPM_BEHAVIOR PI_NPM_SLEEP
    fixture_dir="$(mktemp -d)"
    create_stubs "$fixture_dir"
    render_fixture "$fixture_dir"

    MOCK_NEOVIM_LATEST="2.0.0"
    MOCK_PI_LATEST="2.0.0"
    PI_NPM_BEHAVIOR="ok"
    PI_NPM_SLEEP="4"

    log="${fixture_dir}/run.log"
    run_bump_bg "$fixture_dir" "$log" --all --skip-sha
    pid="$BUMP_BG_PID"

    if ! wait_for_progress "$fixture_dir" "$log" "pi: checking for updates..." 6; then
        fail "Timed out waiting for bump progress before signalling"
    fi

    if [ -n "${pid}" ]; then
        kill -TERM "$pid"
    fi

    if [ -n "${pid}" ] && wait "$pid"; then
        status=0
    else
        status=$?
    fi

    if [ "$status" -eq "$TERM_EXIT_CODE" ]; then
        pass "SIGTERM during --all should return ${TERM_EXIT_CODE} and be catchable"
    else
        fail "SIGTERM during --all should return ${TERM_EXIT_CODE} and be catchable (got=${status})"
    fi
    assert_file_contains "$log" "Rolling back all dependency changes" "Signal rollback should be logged"
    assert_toml_section_value "${fixture_dir}/.local/share/chezmoi/.chezmoidata.toml" "pinned.neovim" "version" "1.0.0" "Neovim pin restored after signal"
    assert_file_contains "${fixture_dir}/.local/share/chezmoi/dot_local/share/pi-cli/package.json" '"@earendil-works/pi-coding-agent": "1.0.0"' "Pi package restored after signal"
    assert_file_contains "${fixture_dir}/.local/share/chezmoi/dot_pi/agent/settings.json" '"lastChangelogVersion": "1.0.0"' "Pi settings restored after signal"
    assert_path_absent "${fixture_dir}/.local/state/chezmoi-maintenance/chezmoi-bump" "Lock removed after signal"

    if [ -n "${pid}" ] && kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    fi
    rm -rf "$fixture_dir"

    BUMP_BG_PID=""
}

test_no_rollback_flag_keeps_outer_atomicity() {
    local fixture_dir log status
    local MOCK_NEOVIM_LATEST MOCK_PI_LATEST PI_NPM_BEHAVIOR PI_NPM_SLEEP
    fixture_dir="$(mktemp -d)"
    create_stubs "$fixture_dir"
    render_fixture "$fixture_dir"

    MOCK_NEOVIM_LATEST="2.0.0"
    MOCK_PI_LATEST="2.0.0"
    PI_NPM_BEHAVIOR="wrong"
    PI_NPM_SLEEP="0"

    log="${fixture_dir}/run.log"
    if run_bump "$fixture_dir" "$log" --all --skip-sha --no-rollback; then
        status=0
    else
        status=$?
    fi

    if [ "$status" -ne 0 ]; then
        pass "--all --no-rollback returns non-zero on a later dependency failure"
    else
        fail "--all --no-rollback returns non-zero on a later dependency failure"
    fi
    assert_file_contains "$log" "Rolling back all dependency changes" "Outer rollback remains enabled with --no-rollback"
    assert_toml_section_value "${fixture_dir}/.local/share/chezmoi/.chezmoidata.toml" "pinned.neovim" "version" "1.0.0" "Outer rollback restores Neovim with --no-rollback"
    assert_file_contains "${fixture_dir}/.local/share/chezmoi/dot_local/share/pi-cli/package.json" '"@earendil-works/pi-coding-agent": "1.0.0"' "Outer rollback restores Pi with --no-rollback"
    assert_path_absent "${fixture_dir}/.local/state/chezmoi-maintenance/chezmoi-bump" "Outer lock removed with --no-rollback"

    rm -rf "$fixture_dir"
}

test_no_update_run_leaves_no_lock() {
    local fixture_dir log status
    local MOCK_NEOVIM_LATEST MOCK_PI_LATEST PI_NPM_BEHAVIOR PI_NPM_SLEEP
    fixture_dir="$(mktemp -d)"
    create_stubs "$fixture_dir"
    render_fixture "$fixture_dir"

    MOCK_NEOVIM_LATEST="1.0.0"
    MOCK_PI_LATEST="1.0.0"
    PI_NPM_BEHAVIOR="ok"
    PI_NPM_SLEEP="0"

    log="${fixture_dir}/run.log"
    if run_bump "$fixture_dir" "$log" --all --skip-sha --force; then
        status=0
    else
        status=$?
    fi

    assert_eq "$status" "0" "No-update --all succeeds"
    assert_file_contains "$log" "All dependencies are up to date" "No-update --all reports a no-op"
    assert_path_absent "${fixture_dir}/.local/state/chezmoi-maintenance/chezmoi-bump" "No-update --all leaves no lock"
    assert_toml_section_value "${fixture_dir}/.local/share/chezmoi/.chezmoidata.toml" "pinned.neovim" "version" "1.0.0" "No-update --all leaves source unchanged"

    rm -rf "$fixture_dir"
}

run_test() {
    local name="$1"
    local fn="$2"

    log "[TEST] ${name}"
    if "$fn"; then
        return 0
    else
        fail "${name} aborted with status $?"
        return 0
    fi
}

run_test "atomic rollback on later dependency failure" test_atomic_rollback_on_inner_failure
run_test "atomic --all succeeds with multiple dependency mutations" test_atomic_success_multiple_targets
run_test "atomic --all reports lock contention" test_lock_contention_fails
run_test "atomic --all restores on catchable signal" test_signal_rolls_back
run_test "outer atomicity overrides per-dependency --no-rollback" test_no_rollback_flag_keeps_outer_atomicity
run_test "no-update --all leaves no lock" test_no_update_run_leaves_no_lock

log ""
log "Tests run: ${PASS_COUNT}/$((PASS_COUNT + FAIL_COUNT))"
log "Failures: ${FAIL_COUNT}"

if [ "$FAIL_COUNT" -ne 0 ]; then
    exit 1
fi
exit 0
