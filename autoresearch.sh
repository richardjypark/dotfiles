#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import subprocess
import time

loops = 5
start = time.perf_counter()
for _ in range(loops):
    subprocess.run(['bash', './autoresearch.checks.sh'], check=True)
elapsed_ms = (time.perf_counter() - start) * 1000

print(f'Benchmark runs: {loops}')
print(f'METRIC total_ms={elapsed_ms:.2f}')
print(f'METRIC per_run_ms={elapsed_ms/loops:.2f}')
print(f'METRIC loops={loops}')
PY
