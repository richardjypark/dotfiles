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
    if ! download_file "$url" "$tmp_file"; then
        rm -f "$tmp_file"
        return 1
    fi

    if ! verify_sha256 "$tmp_file" "$expected_sha"; then
        eecho "Error: checksum verification failed for $url"
        rm -f "$tmp_file"
        return 1
    fi

    mv "$tmp_file" "$destination"
    vecho "Downloaded and verified artifact: $destination"
    return 0
}

# Activate only a command that starts successfully. Keep the old target until
# the replacement has been copied and checked in the destination directory.
install_checked_binary() {
    local source="$1" destination="$2" staged
    [ -f "$source" ] || return 1
    [ ! -L "$source" ] || return 1
    [ -x "$source" ] || return 1
    "$source" --version >/dev/null 2>&1 || return 1
    mkdir -p "$(dirname "$destination")" || return 1
    staged="$(mktemp "${destination}.tmp.XXXXXXXX")" || return 1
    if ! install -m 755 "$source" "$staged"; then
        rm -f "$staged"
        return 1
    fi
    if ! "$staged" --version >/dev/null 2>&1; then
        rm -f "$staged"
        return 1
    fi
    if ! mv -f "$staged" "$destination"; then
        rm -f "$staged"
        return 1
    fi
}
