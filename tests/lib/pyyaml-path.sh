#!/usr/bin/env bash
set -euo pipefail

PYYAML_VERSION=6.0.3
PYYAML_SHA256=d76623373421df22fb4cf8817020cbb7ef15c725b9d5e45f17e189bfc384190f

. "$(dirname "${BASH_SOURCE[0]}")/temp.sh"

dest="${1:-${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-tests/pyyaml-$PYYAML_VERSION}"
if [ -f "$dest/yaml/__init__.py" ]; then
    printf '%s\n' "$dest"
    exit 0
fi
if [ -e "$dest" ]; then
    printf 'pyyaml-path: %s exists but holds no PyYAML package; move it aside and retry\n' "$dest" >&2
    exit 1
fi

new_test_temp_dir work
trap 'remove_test_temp_dir "$work"' EXIT
archive="$work/pyyaml-$PYYAML_VERSION.tar.gz"
curl --fail --location --silent --show-error --proto '=https' --output "$archive" \
    "https://files.pythonhosted.org/packages/source/p/pyyaml/pyyaml-$PYYAML_VERSION.tar.gz"
printf '%s  %s\n' "$PYYAML_SHA256" "$archive" | shasum -a 256 --check --status
mkdir -p "$work/out" "$(dirname "$dest")"
tar -xzf "$archive" -C "$work/out" --strip-components=2 "pyyaml-$PYYAML_VERSION/lib/yaml"
mv "$work/out" "$dest"
printf '%s\n' "$dest"
