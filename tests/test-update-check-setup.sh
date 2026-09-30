#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
. "$REPO_ROOT/tests/lib/temp.sh"
new_test_temp_dir fixture
trap 'remove_test_temp_dir "$fixture"' EXIT

mkdir -p "$fixture/home/.local/lib" "$fixture/bin"
cat > "$fixture/home/.local/lib/chezmoi-helpers.sh" <<'EOF'
eecho() { printf '%s\n' "$*"; }
vecho() { :; }
EOF
cat > "$fixture/bin/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${TEST_OS:-Linux}"
EOF
cat > "$fixture/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${TEST_CALLS:?}"
case "$*" in
    '--user show-environment') exit "${TEST_MANAGER_STATUS:-0}" ;;
    '--user is-enabled dotfiles-update-check.timer') exit "${TEST_ENABLED_STATUS:-1}" ;;
esac
EOF
chmod +x "$fixture/bin/uname" "$fixture/bin/systemctl"

run_setup() {
    local role="$1" profile="$2"
    : > "$fixture/calls"
    CHEZMOI_ROLE="$role" CHEZMOI_PROFILE="$profile" \
        chezmoi --source "$REPO_ROOT" execute-template \
        < "$REPO_ROOT/.chezmoiscripts/run_onchange_after_92-setup-update-check.sh.tmpl" \
        > "$fixture/setup.sh"
    HOME="$fixture/home" PATH="$fixture/bin:$PATH" TEST_CALLS="$fixture/calls" \
        bash "$fixture/setup.sh"
}

run_setup workstation omarchy
rg -q -- '--user enable --now dotfiles-update-check.timer' "$fixture/calls"
run_setup workstation omarchy
rg -q -- '--user enable --now dotfiles-update-check.timer' "$fixture/calls"
printf '[PASS] repeated workstation setup enables the check timer\n'

for settings in 'server omarchy' 'workstation standard'; do
    read -r role profile <<< "$settings"
    TEST_ENABLED_STATUS=0 run_setup "$role" "$profile"
    rg -q -- '--user disable --now dotfiles-update-check.timer' "$fixture/calls"
    if rg -q -- '--user enable --now' "$fixture/calls"; then exit 1; fi
done
printf '[PASS] server and standard profiles disable an existing timer\n'

TEST_MANAGER_STATUS=1 run_setup workstation omarchy
if rg -q -- '--user enable --now' "$fixture/calls"; then exit 1; fi
printf '[PASS] an unavailable user manager does not enable the timer\n'

TEST_OS=Darwin run_setup workstation omarchy
test ! -s "$fixture/calls"
printf '[PASS] non-Linux setup skips systemd\n'

for settings in 'workstation omarchy' 'server omarchy' 'workstation standard'; do
    read -r role profile <<< "$settings"
    CHEZMOI_ROLE="$role" CHEZMOI_PROFILE="$profile" \
        chezmoi --source "$REPO_ROOT" execute-template < "$REPO_ROOT/.chezmoiignore" \
        > "$fixture/ignore"
    if [ "$role/$profile/$(uname -s)" = workstation/omarchy/Linux ]; then
        if rg -q '^\.config/systemd/user/dotfiles-update-check\.timer$' "$fixture/ignore"; then exit 1; fi
    else
        rg -q '^\.config/systemd/user/dotfiles-update-check\.timer$' "$fixture/ignore"
    fi
done
printf '[PASS] timer targets use the Linux Omarchy workstation path gate\n'
