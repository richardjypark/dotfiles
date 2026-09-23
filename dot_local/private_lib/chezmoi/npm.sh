# --- Managed npm Safety Helpers ---

resolve_npm_cmd() {
    local candidate resolved
    if command -v mise >/dev/null 2>&1; then
        candidate="$(cd "$HOME" && mise which npm 2>/dev/null || true)"
        if [ -n "$candidate" ] && [ -x "$candidate" ] && "$candidate" -v >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return 0
        fi
    fi
    if command -v npm >/dev/null 2>&1; then
        candidate="$(command -v npm)"
        resolved="$candidate"
        if command -v readlink >/dev/null 2>&1; then
            resolved="$(readlink -f "$candidate" 2>/dev/null || printf '%s\n' "$candidate")"
        fi
        if [ -x "$resolved" ] && "$resolved" -v >/dev/null 2>&1; then
            printf '%s\n' "$resolved"
            return 0
        fi
        if [ -x "$candidate" ] && "$candidate" -v >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return 0
        fi
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
    local mode="${2:-production}"

    if [ ! -f "$project_dir/package-lock.json" ]; then
        eecho "Error: missing committed npm lockfile at $project_dir/package-lock.json"
        return 1
    fi

    case "$mode" in
        production|build) ;;
        *) eecho "Error: unsupported managed npm mode: $mode"; return 1 ;;
    esac
    (
        cd "$project_dir" || exit 1
        if [ "$mode" = "build" ]; then
            NPM_CONFIG_REGISTRY="$(npm_registry_url)" \
            NPM_CONFIG_REPLACE_REGISTRY_HOST=always \
                run_quiet "$NPM_CMD" ci --include=dev --ignore-scripts --no-fund --no-audit
        else
            NPM_CONFIG_REGISTRY="$(npm_registry_url)" \
            NPM_CONFIG_REPLACE_REGISTRY_HOST=always \
                run_quiet "$NPM_CMD" ci --ignore-scripts --no-fund --no-audit --omit=dev
        fi
    )
}
