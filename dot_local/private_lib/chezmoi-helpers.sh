#!/usr/bin/env bash
# chezmoi-helpers.sh — shared helper library for chezmoi scripts
# Sourced by all .chezmoiscripts/ files via: . "$HOME/.local/lib/chezmoi-helpers.sh"

# Guard against double-sourcing
if [ -n "${CHEZMOI_HELPERS_LOADED:-}" ]; then return 0 2>/dev/null || true; fi

# --- Output Helpers ---

VERBOSE="${VERBOSE:-false}"

vecho() {
    if [ "$VERBOSE" = "true" ]; then
        echo "$@"
    fi
}

eecho() { echo "$@"; }

# --- State Tracking ---

STATE_DIR="${STATE_DIR:-$HOME/.cache/chezmoi-state}"

# Ensure state directory exists (created once per apply run)
[ -d "$STATE_DIR" ] || mkdir -p "$STATE_DIR"

# Check if a setup step was completed
state_exists() {
    [ -f "$STATE_DIR/$1.done" ]
}

# Mark a setup step as complete
mark_state() {
    touch "$STATE_DIR/$1.done"
}

# Clear a setup state (useful for forced re-runs)
clear_state() {
    rm -f "$STATE_DIR/$1.done"
}

is_force_update() {
    [ "${CHEZMOI_FORCE_UPDATE:-0}" = "1" ]
}

is_macos_maintenance_mode() {
    [ "${CHEZMOI_MACOS_MAINTENANCE_MODE:-0}" = "1" ]
}

should_skip_state() {
    local state_name="$1"
    if state_exists "$state_name" && ! is_force_update; then
        return 0
    fi
    return 1
}

# --- PATH Management ---

# Add a directory to PATH if not already present
add_to_path() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) export PATH="$1:$PATH" ;;
    esac
}

# --- Command Detection ---

# Check if a command is available
is_installed() {
    command -v "$1" >/dev/null 2>&1
}

# --- Privilege Escalation ---

TRUST_ON_FIRST_USE_INSTALLERS="${TRUST_ON_FIRST_USE_INSTALLERS:-0}"
CHEZMOI_DISABLE_SUDO="${CHEZMOI_DISABLE_SUDO:-0}"

# Download/cache settings
CHEZMOI_PREFETCH_JOBS="${CHEZMOI_PREFETCH_JOBS:-4}"
CHEZMOI_DOWNLOAD_CACHE_DIR="${CHEZMOI_DOWNLOAD_CACHE_DIR:-$HOME/.cache/chezmoi-downloads}"

sudo_disabled() {
    case "${CHEZMOI_DISABLE_SUDO:-0}" in
        1|true|TRUE|yes|YES)
            return 0
            ;;
    esac
    return 1
}

# Check if we can run privileged commands (root or passwordless sudo)
ensure_sudo() {
    if sudo_disabled; then
        return 1
    fi
    if [ "$(id -u)" = 0 ]; then
        return 0
    fi
    if sudo -n true 2>/dev/null; then
        return 0
    fi
    if [ "${CHEZMOI_BOOTSTRAP_ALLOW_INTERACTIVE_SUDO:-0}" = "1" ] && [ -t 0 ]; then
        eecho "Requesting sudo access for package installation..."
        sudo -v >/dev/null 2>&1 || return 1
        sudo -n true 2>/dev/null || return 1
        return 0
    fi
    return 1
}

# Run a command with privilege escalation if needed
run_privileged() {
    if sudo_disabled; then
        return 1
    fi
    if [ "$(id -u)" = 0 ]; then
        "$@"
    elif ensure_sudo; then
        sudo "$@"
    else
        return 1
    fi
}

require_trust_for_remote_installer() {
    local installer="$1"
    if [ "$TRUST_ON_FIRST_USE_INSTALLERS" != "1" ]; then
        eecho "Refusing to run remote installer without explicit trust."
        eecho "Re-run with TRUST_ON_FIRST_USE_INSTALLERS=1 to allow ${installer}."
        return 1
    fi
    return 0
}

require_trust_for_remote_download() {
    local source="$1"
    if [ "$TRUST_ON_FIRST_USE_INSTALLERS" != "1" ]; then
        eecho "Refusing to fetch remote artifact without explicit trust."
        eecho "Re-run with TRUST_ON_FIRST_USE_INSTALLERS=1 to allow download from ${source}."
        return 1
    fi
    return 0
}

detect_normalized_os() {
    case "$(uname -s)" in
        Linux) printf '%s\n' "linux" ;;
        Darwin) printf '%s\n' "macos" ;;
        *)
            eecho "Unsupported OS: $(uname -s)"
            return 1
            ;;
    esac
}

detect_normalized_arch() {
    case "$(uname -m)" in
        x86_64|amd64) printf '%s\n' "x86_64" ;;
        aarch64|arm64) printf '%s\n' "arm64" ;;
        *)
            eecho "Unsupported architecture: $(uname -m)"
            return 1
            ;;
    esac
}

detect_platform() {
    local os arch
    os="$(detect_normalized_os)" || return 1
    arch="$(detect_normalized_arch)" || return 1
    printf '%s %s\n' "$os" "$arch"
}

platform_key() {
    local os arch
    if ! read -r os arch <<EOF
$(detect_platform)
EOF
    then
        return 1
    fi
    printf '%s-%s\n' "$os" "$arch"
}

sha256_file() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
        return 0
    fi
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
        return 0
    fi
    eecho "Error: no SHA-256 tool found (need sha256sum or shasum)."
    return 1
}

verify_sha256() {
    local file="$1"
    local expected="$2"
    local actual

    if [ ! -f "$file" ]; then
        return 1
    fi

    actual="$(sha256_file "$file")" || return 1
    [ "$actual" = "$expected" ]
}

download_file() {
    local url="$1"
    local destination="$2"
    local destination_dir
    destination_dir="$(dirname "$destination")"
    mkdir -p "$destination_dir"

    curl --fail --location --show-error --silent \
        --proto '=https' --tlsv1.2 \
        --retry 3 --retry-delay 2 \
        --connect-timeout 10 --max-time 300 \
        "$url" -o "$destination"
}

download_and_verify() {
    local url="$1"
    local destination="$2"
    local expected_sha="$3"
    local tmp_file

    if [ -f "$destination" ] && verify_sha256 "$destination" "$expected_sha"; then
        vecho "Using verified cached artifact: $destination"
        return 0
    fi

    if [ -f "$destination" ]; then
        vecho "Cached artifact checksum mismatch, re-downloading: $destination"
    else
        vecho "Cache miss, downloading artifact: $destination"
    fi

    tmp_file="${destination}.tmp.$$"
    rm -f "$tmp_file"
    download_file "$url" "$tmp_file"

    if ! verify_sha256 "$tmp_file" "$expected_sha"; then
        eecho "Error: checksum verification failed for $url"
        rm -f "$tmp_file"
        return 1
    fi

    mv "$tmp_file" "$destination"
    vecho "Downloaded and verified artifact: $destination"
    return 0
}

# --- Managed npm Safety Helpers ---

resolve_npm_cmd() {
    local nvm_dir current_node nvm_bin candidate resolved

    nvm_dir="$HOME/.nvm"
    if [ -f "$nvm_dir/nvm.sh" ]; then
        . "$nvm_dir/nvm.sh" >/dev/null 2>&1 || true
        if command -v nvm >/dev/null 2>&1; then
            nvm use default >/dev/null 2>&1 || true
            current_node="$(nvm which current 2>/dev/null || true)"
            if [ -n "$current_node" ] && [ -x "$current_node" ]; then
                nvm_bin="$(dirname "$current_node")"
                if [ -x "$nvm_bin/npm" ] && "$nvm_bin/npm" -v >/dev/null 2>&1; then
                    NPM_CMD="$nvm_bin/npm"
                    return 0
                fi
            fi
        fi
    fi

    if is_installed npm; then
        candidate="$(command -v npm)"
        resolved="$candidate"
        if command -v readlink >/dev/null 2>&1; then
            resolved="$(readlink -f "$candidate" 2>/dev/null || printf '%s\n' "$candidate")"
        fi
        if [ -x "$resolved" ] && "$resolved" -v >/dev/null 2>&1; then
            NPM_CMD="$resolved"
        else
            NPM_CMD="$candidate"
        fi
        return 0
    fi

    return 1
}

npm_registry_url() {
    local registry
    registry="${CHEZMOI_NPM_REGISTRY:-${NPM_CONFIG_REGISTRY:-https://registry.npmjs.org/}}"
    registry="${registry%/}"
    printf '%s\n' "$registry"
}

npm_registry_is_public() {
    case "$(npm_registry_url)" in
        https://registry.npmjs.org|http://registry.npmjs.org|registry.npmjs.org)
            return 0
            ;;
    esac
    return 1
}

npm_min_version_age_days() {
    local value
    value="${CHEZMOI_NPM_MIN_VERSION_AGE_DAYS:-3}"
    case "$value" in
        ''|0)
            printf '0\n'
            return 0
            ;;
        *[!0-9]*)
            eecho "Error: CHEZMOI_NPM_MIN_VERSION_AGE_DAYS must be a non-negative integer."
            return 1
            ;;
    esac
    printf '%s\n' "$value"
}

resolve_node_cmd() {
    local node_cmd

    node_cmd="$(dirname "$NPM_CMD")/node"
    if [ -x "$node_cmd" ]; then
        printf '%s\n' "$node_cmd"
        return 0
    fi

    node_cmd="$(command -v node 2>/dev/null || true)"
    if [ -n "$node_cmd" ] && [ -x "$node_cmd" ]; then
        printf '%s\n' "$node_cmd"
        return 0
    fi

    return 1
}

npm_publish_metadata_cache_file() {
    local package="$1"
    local cache_dir cache_key

    cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/chezmoi-npm-publish-time"
    mkdir -p "$cache_dir"
    cache_key="$(printf '%s__%s' "$(npm_registry_url)" "$package" | tr -c 'A-Za-z0-9._-' '_')"
    printf '%s/%s.json\n' "$cache_dir" "$cache_key"
}

npm_query_publish_metadata_json() {
    local package="$1"
    local force_refresh="${2:-0}"
    local cache_file metadata

    cache_file="$(npm_publish_metadata_cache_file "$package")"
    if [ "$force_refresh" != "1" ] && [ -s "$cache_file" ]; then
        cat "$cache_file"
        return 0
    fi

    metadata="$(NPM_CONFIG_REGISTRY="$(npm_registry_url)" "$NPM_CMD" view "$package" time --json 2>/dev/null || true)"
    if [ -z "$metadata" ]; then
        return 1
    fi

    printf '%s\n' "$metadata" > "$cache_file"
    printf '%s\n' "$metadata"
}

npm_query_publish_epoch() {
    local package="$1"
    local version="$2"
    local metadata node_cmd published_epoch

    metadata="$(npm_query_publish_metadata_json "$package" || true)"
    if [ -z "$metadata" ]; then
        return 1
    fi

    node_cmd="$(resolve_node_cmd || true)"
    if [ -z "$node_cmd" ]; then
        return 1
    fi

    published_epoch="$(printf '%s' "$metadata" | "$node_cmd" -e '
const fs = require("fs")
const version = process.argv[1]
const raw = fs.readFileSync(0, "utf8").trim()
if (!raw) process.exit(1)
let data
try {
  data = JSON.parse(raw)
} catch {
  process.exit(1)
}
const timestamp = data && data[version]
if (!timestamp) process.exit(1)
const epochMs = Date.parse(timestamp)
if (!Number.isFinite(epochMs)) process.exit(1)
process.stdout.write(String(Math.floor(epochMs / 1000)))
' "$version" 2>/dev/null || true)"
    if [ -n "$published_epoch" ]; then
        printf '%s\n' "$published_epoch"
        return 0
    fi

    metadata="$(npm_query_publish_metadata_json "$package" 1 || true)"
    if [ -z "$metadata" ]; then
        return 1
    fi

    published_epoch="$(printf '%s' "$metadata" | "$node_cmd" -e '
const fs = require("fs")
const version = process.argv[1]
const raw = fs.readFileSync(0, "utf8").trim()
if (!raw) process.exit(1)
let data
try {
  data = JSON.parse(raw)
} catch {
  process.exit(1)
}
const timestamp = data && data[version]
if (!timestamp) process.exit(1)
const epochMs = Date.parse(timestamp)
if (!Number.isFinite(epochMs)) process.exit(1)
process.stdout.write(String(Math.floor(epochMs / 1000)))
' "$version" 2>/dev/null || true)"
    [ -n "$published_epoch" ] || return 1
    printf '%s\n' "$published_epoch"
}

npm_require_minimum_version_age() {
    local package="$1"
    local version="$2"
    local min_days min_seconds published_epoch now_epoch age_seconds registry

    min_days="$(npm_min_version_age_days)" || return 1
    case "$min_days" in
        0)
            return 0
            ;;
    esac

    registry="$(npm_registry_url)"
    published_epoch="$(npm_query_publish_epoch "$package" "$version" || true)"
    if [ -z "$published_epoch" ]; then
        if npm_registry_is_public; then
            eecho "Error: could not verify npm publish time for ${package}@${version} from ${registry}."
            eecho "Set CHEZMOI_NPM_REGISTRY to a vetted internal proxy, or set CHEZMOI_NPM_MIN_VERSION_AGE_DAYS=0 to bypass the age gate deliberately."
            return 1
        fi
        vecho "Skipping npm publish-age check for ${package}@${version}; registry ${registry} did not expose publish metadata."
        return 0
    fi

    now_epoch="$(date +%s)"
    min_seconds=$((min_days * 86400))
    age_seconds=$((now_epoch - published_epoch))
    if [ "$age_seconds" -lt "$min_seconds" ]; then
        eecho "Refusing to install ${package}@${version}: npm publish age is below ${min_days} day(s)."
        eecho "Wait for the update delay to pass, or set CHEZMOI_NPM_MIN_VERSION_AGE_DAYS=0 to bypass intentionally."
        return 1
    fi

    return 0
}

npm_lockfile_package_specs() {
    local lockfile="$1"
    local node_cmd

    if [ ! -f "$lockfile" ]; then
        eecho "Error: missing npm lockfile at $lockfile"
        return 1
    fi

    node_cmd="$(resolve_node_cmd || true)"
    if [ -z "$node_cmd" ]; then
        eecho "Error: node is required to inspect npm lockfiles."
        return 1
    fi

    "$node_cmd" -e '
const fs = require("fs")
const lockfilePath = process.argv[1]
const raw = fs.readFileSync(lockfilePath, "utf8")
const lock = JSON.parse(raw)
const packages = lock && lock.packages ? lock.packages : {}
const seen = new Set()
const rows = []
for (const [packagePath, meta] of Object.entries(packages)) {
  if (!packagePath || !meta || typeof meta.version !== "string") continue
  let name = typeof meta.name === "string" && meta.name ? meta.name : ""
  if (!name) {
    const match = packagePath.match(/node_modules\/((?:@[^/]+\/)?[^/]+)$/)
    name = match ? match[1] : ""
  }
  if (!name) continue
  if (!/^[0-9]+(?:\.[0-9]+)*(?:[-+][0-9A-Za-z.-]+)?$/.test(meta.version)) continue
  const spec = `${name}\t${meta.version}`
  if (seen.has(spec)) continue
  seen.add(spec)
  rows.push(spec)
}
rows.sort((a, b) => a.localeCompare(b))
if (rows.length > 0) process.stdout.write(`${rows.join("\n")}\n`)
' "$lockfile"
}

npm_require_minimum_lockfile_age() {
    local lockfile="$1"
    local min_days specs spec_count package version

    min_days="$(npm_min_version_age_days)" || return 1
    case "$min_days" in
        0)
            return 0
            ;;
    esac

    specs="$(npm_lockfile_package_specs "$lockfile")" || return 1
    if [ -z "$specs" ]; then
        eecho "Error: could not find any versioned packages in $lockfile"
        return 1
    fi

    spec_count="$(printf '%s\n' "$specs" | wc -l | awk '{print $1}')"
    vecho "Checking npm publish-age policy for ${spec_count} locked package version(s) in $lockfile"

    while IFS=$'\t' read -r package version; do
        [ -n "$package" ] || continue
        npm_require_minimum_version_age "$package" "$version" || return 1
    done <<EOF
$specs
EOF
}

run_managed_npm_ci() {
    local project_dir="$1"

    if [ ! -f "$project_dir/package-lock.json" ]; then
        eecho "Error: missing committed npm lockfile at $project_dir/package-lock.json"
        return 1
    fi

    if [ "$VERBOSE" = "true" ]; then
        (
            cd "$project_dir"
            NPM_CONFIG_REGISTRY="$(npm_registry_url)" \
            NPM_CONFIG_REPLACE_REGISTRY_HOST=always \
                "$NPM_CMD" ci --ignore-scripts --no-fund --no-audit --omit=dev
        )
    else
        (
            cd "$project_dir"
            NPM_CONFIG_REGISTRY="$(npm_registry_url)" \
            NPM_CONFIG_REPLACE_REGISTRY_HOST=always \
                "$NPM_CMD" ci --ignore-scripts --no-fund --no-audit --omit=dev >/dev/null 2>&1
        )
    fi
}

# --- Convenience Wrappers ---

# Run a command, suppressing stdout/stderr unless VERBOSE=true.
# Usage: run_quiet cmd arg1 arg2 ...
run_quiet() {
    if [ "$VERBOSE" = "true" ]; then
        "$@"
    else
        "$@" >/dev/null 2>&1
    fi
}

# --- Version Comparison ---

# Generic semver comparison (MAJOR.MINOR.PATCH).
# Returns 0 (true) if $1 >= $2, 1 (false) otherwise.
# Usage: version_ge "1.2.3" "1.2.0" && echo "ok"
version_ge() {
    local current required
    local c1 c2 c3 r1 r2 r3

    current="${1:-0.0.0}"
    required="${2:-0.0.0}"

    IFS=. read -r c1 c2 c3 <<EOF
$current
EOF
    IFS=. read -r r1 r2 r3 <<EOF
$required
EOF

    c1=${c1:-0}; c2=${c2:-0}; c3=${c3:-0}
    r1=${r1:-0}; r2=${r2:-0}; r3=${r3:-0}

    if [ "$c1" -gt "$r1" ]; then return 0; fi
    if [ "$c1" -lt "$r1" ]; then return 1; fi
    if [ "$c2" -gt "$r2" ]; then return 0; fi
    if [ "$c2" -lt "$r2" ]; then return 1; fi
    if [ "$c3" -ge "$r3" ]; then return 0; fi
    return 1
}

normalize_version_token() {
    local value="${1:-}"
    value="${value#rust-v}"
    value="${value#bun-v}"
    value="${value#v}"
    value="${value%%-*}"
    printf '%s\n' "$value"
}

CHEZMOI_HELPERS_LOADED=1
