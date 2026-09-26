# --- Managed npm Safety Helpers ---

npm_validate_automatic_policy() {
    [ "${CHEZMOI_AUTOMATIC_UPDATES:-0}" = "1" ] || return 0
    if [ "${CHEZMOI_NPM_MIN_VERSION_AGE_DAYS:-7}" != "7" ]; then
        eecho "Error: automatic npm updates require a seven-day delay."
        return 1
    fi
    local setting value
    for setting in CHEZMOI_NPM_REGISTRY NPM_CONFIG_REGISTRY npm_config_registry; do
        value="${!setting:-https://registry.npmjs.org}"
        if [ "${value%/}" != "https://registry.npmjs.org" ]; then
            eecho "Error: automatic npm updates require the public HTTPS registry."
            return 1
        fi
    done
}

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
    npm_validate_automatic_policy || return 1
    if [ "${CHEZMOI_AUTOMATIC_UPDATES:-0}" = "1" ]; then
        printf '7\n'
        return 0
    fi
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
    local cache_dir cache_key min_days

    min_days="$(npm_min_version_age_days)" || return 1
    cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/chezmoi-npm-publish-time"
    mkdir -p "$cache_dir"
    cache_key="$(printf '%s__%s__%s' "$(npm_registry_url)" "$package" "$min_days" | tr -c 'A-Za-z0-9._-' '_')"
    printf '%s/%s.json\n' "$cache_dir" "$cache_key"
}

npm_publish_metadata_cache_is_fresh() {
    local file="$1" now mtime
    [ -s "$file" ] || return 1
    now="$(date +%s)"
    mtime="$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)" || return 1
    [ "$mtime" -le "$now" ] && [ "$((now - mtime))" -lt 86400 ]
}

npm_query_publish_metadata_json() {
    local package="$1"
    local force_refresh="${2:-0}"
    local cache_file metadata node_cmd temporary

    npm_validate_automatic_policy || return 1
    cache_file="$(npm_publish_metadata_cache_file "$package")" || return 1
    if [ "${CHEZMOI_AUTOMATIC_UPDATES:-0}" = "1" ]; then
        force_refresh=1
    fi
    if [ "$force_refresh" != "1" ] && npm_publish_metadata_cache_is_fresh "$cache_file"; then
        cat "$cache_file"
        return 0
    fi

    if [ "${CHEZMOI_AUTOMATIC_UPDATES:-0}" = "1" ]; then
        node_cmd="$(resolve_node_cmd)" || return 1
        # Query the public origin directly; scoped registries in .npmrc must
        # not supply publication times for automatic proposals.
        metadata="$("$node_cmd" -e '
fetch(`https://registry.npmjs.org/${encodeURIComponent(process.argv[1])}`, {
  redirect: "error", signal: AbortSignal.timeout(20000), headers: {"Cache-Control": "no-cache"}
}).then(response => {
  if (!response.ok) throw new Error("metadata request failed")
  return response.json()
}).then(data => {
  for (const field of [data.time, data.versions]) {
    if (!field || typeof field !== "object" || Array.isArray(field)) throw new Error("invalid metadata")
  }
  const times = Object.fromEntries(Object.keys(data.versions).map(version => [version, data.time[version]]))
  process.stdout.write(JSON.stringify(times))
}).catch(() => process.exit(1))
' "$package")" || return 1
    else
        metadata="$(NPM_CONFIG_REGISTRY="$(npm_registry_url)" "$NPM_CMD" view "$package" time --json 2>/dev/null)" || return 1
    fi
    if [ -z "$metadata" ]; then
        return 1
    fi

    temporary="$(mktemp "${cache_file}.XXXXXXXX")" || return 1
    printf '%s\n' "$metadata" > "$temporary"
    mv "$temporary" "$cache_file"
    printf '%s\n' "$metadata"
}

npm_publish_epoch_from_json() {
    local node_cmd="$1" version="$2"
    "$node_cmd" -e '
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
if (process.env.CHEZMOI_AUTOMATIC_UPDATES === "1") {
  if (typeof timestamp !== "string") process.exit(1)
  const fields = timestamp.match(/^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)(?:\.\d+)?(?:Z|[+-](\d\d):(\d\d))$/)
  if (!fields) process.exit(1)
  const [year, month, day, hour, minute, second, offsetHour = 0, offsetMinute = 0] = fields.slice(1).map(value => value === undefined ? 0 : Number(value))
  const leap = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0)
  const monthDays = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  if (year < 1 || month < 1 || month > 12 || day < 1 || day > monthDays[month - 1] ||
      hour > 23 || minute > 59 || second > 59 || offsetHour > 23 || offsetMinute > 59) process.exit(1)
}
const epochMs = Date.parse(timestamp)
if (!Number.isFinite(epochMs) || epochMs > Date.now()) process.exit(1)
// Round up so the second-resolution age check cannot accept a release early.
process.stdout.write(String(Math.ceil(epochMs / 1000)))
' "$version" 2>/dev/null
}

npm_query_publish_epoch() {
    local package="$1" version="$2"
    local metadata node_cmd published_epoch refresh

    node_cmd="$(resolve_node_cmd)" || return 1
    for refresh in 0 1; do
        metadata="$(npm_query_publish_metadata_json "$package" "$refresh")" || return 1
        if published_epoch="$(printf '%s' "$metadata" | npm_publish_epoch_from_json "$node_cmd" "$version")"; then
            printf '%s\n' "$published_epoch"
            return 0
        fi
        # Automatic queries are already fresh; a retry cannot repair metadata.
        [ "${CHEZMOI_AUTOMATIC_UPDATES:-0}" != "1" ] || break
    done
    return 1
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
        if [ "${CHEZMOI_AUTOMATIC_UPDATES:-0}" = "1" ]; then
            eecho "Error: automatic mode requires exact public npm publish metadata for ${package}@${version}."
            return 1
        fi
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
        if [ "${CHEZMOI_AUTOMATIC_UPDATES:-0}" != "1" ]; then
            eecho "Wait for the update delay to pass, or set CHEZMOI_NPM_MIN_VERSION_AGE_DAYS=0 to bypass intentionally."
        fi
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

    npm_validate_automatic_policy || return 1
    "$node_cmd" -e '
const fs = require("fs")
const lockfilePath = process.argv[1]
const raw = fs.readFileSync(lockfilePath, "utf8")
const lock = JSON.parse(raw)
const automatic = process.env.CHEZMOI_AUTOMATIC_UPDATES === "1"
const packages = lock && lock.packages
if (!packages || typeof packages !== "object" || Array.isArray(packages)) process.exit(1)
if (automatic && ![2, 3].includes(lock.lockfileVersion)) process.exit(1)
const seen = new Set()
const rows = []
for (const [packagePath, meta] of Object.entries(packages)) {
  if (!packagePath) continue
  if (!meta || typeof meta.version !== "string") process.exit(1)
  let name = typeof meta.name === "string" && meta.name ? meta.name : ""
  if (!name) {
    const match = packagePath.match(/node_modules\/((?:@[^/]+\/)?[^/]+)$/)
    name = match ? match[1] : ""
  }
  if (!name) process.exit(1)
  if (!/^[0-9]+(?:\.[0-9]+)*(?:[-+][0-9A-Za-z.-]+)?$/.test(meta.version)) process.exit(1)
  if (automatic) {
    if (!/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(meta.version) || meta.link) process.exit(1)
    let resolved
    try { resolved = new URL(meta.resolved) } catch { process.exit(1) }
    if (resolved.protocol !== "https:" || resolved.host !== "registry.npmjs.org" || resolved.username || resolved.password) process.exit(1)
    const tarball = `/${name}/-/${name.split("/").pop()}-${meta.version}.tgz`
    if (decodeURIComponent(resolved.pathname) !== tarball || resolved.search || resolved.hash) process.exit(1)
    const integrity = typeof meta.integrity === "string" && meta.integrity.match(/^sha(256|512)-([A-Za-z0-9+/]+={0,2})$/)
    if (!integrity) {
      console.error(`Error: automatic updates require SHA-256 or SHA-512 integrity for ${JSON.stringify(packagePath)}.`)
      process.exit(1)
    }
    const digest = Buffer.from(integrity[2], "base64")
    if (digest.length !== Number(integrity[1]) / 8 || digest.toString("base64") !== integrity[2]) process.exit(1)
  }
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
