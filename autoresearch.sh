#!/usr/bin/env bash
set -euo pipefail

loops="${AUTORESEARCH_LOOPS:-400}"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

bench_home="$tmpdir/home"
mkdir -p "$bench_home/.local/lib" "$bench_home/.cache/chezmoi-state"
cp dot_local/private_lib/chezmoi-helpers.sh "$bench_home/.local/lib/chezmoi-helpers.sh"

script_path="$tmpdir/run_after_38.sh"
chezmoi execute-template < .chezmoiscripts/run_after_38-setup-pi-maintenance-agent.sh.tmpl > "$script_path"
chmod +x "$script_path"

python3 - "$script_path" "$bench_home" "$loops" <<'PY'
import os
import subprocess
import sys
import time
from pathlib import Path

script_path, bench_home, loops_raw = sys.argv[1:4]
loops = int(loops_raw)

env = os.environ.copy()
env['HOME'] = bench_home
env['VERBOSE'] = 'false'
env.pop('CHEZMOI_PROFILE', None)

for _ in range(25):
    subprocess.run([script_path], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

start = time.perf_counter()
for _ in range(loops):
    subprocess.run([script_path], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
elapsed_us = (time.perf_counter() - start) * 1_000_000

print(f"Benchmark: unsupported-host/no-marker warm path over {loops} loops")
print(f"METRIC total_us={elapsed_us:.0f}")
print(f"METRIC per_run_us={elapsed_us / loops:.2f}")
print(f"METRIC loops={loops}")
PY
