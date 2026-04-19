#!/usr/bin/env bash
set -euo pipefail

loops="${AUTORESEARCH_LOOPS:-400}"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

state_dir="$tmpdir/state"
mkdir -p "$state_dir"
for i in $(seq 1 24); do
  : > "$state_dir/$i.done"
done

python3 - "$tmpdir" "$state_dir" "$loops" <<'PY'
import os
import subprocess
import sys
import time

bench_home, state_dir, loops_raw = sys.argv[1:4]
loops = int(loops_raw)

env = os.environ.copy()
env['HOME'] = bench_home
env['STATE_DIR'] = state_dir
env['VERBOSE'] = 'false'

script = '.chezmoiscripts/run_after_99-performance-summary.sh'

for _ in range(25):
    subprocess.run(['bash', script], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

start = time.perf_counter()
for _ in range(loops):
    subprocess.run(['bash', script], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
elapsed_us = (time.perf_counter() - start) * 1_000_000

print(f"Benchmark: run_after_99 non-verbose warm path over {loops} loops")
print(f"METRIC total_us={elapsed_us:.0f}")
print(f"METRIC per_run_us={elapsed_us / loops:.2f}")
print(f"METRIC loops={loops}")
PY
