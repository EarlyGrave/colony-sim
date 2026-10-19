#!/usr/bin/env bash
# D4 harness: real factory_bot over many seeds in parallel, one godot process per seed.
# Usage: tools/factory_eval.sh [--seeds=1-10] [--days=60] [--preset=standard] [--jobs=N] [--timeout=280] [--ov=JSON] [--nitrogen=1]
# (preset: only "standard" exists for the bot today; accepted for forward compatibility.)
# Output: table + PASS/FAIL vs acceptance (audit>=6, P1>=5, P3>=3, launch>=1 of 10). Temp dir is removed on exit; only own PIDs killed.
set -u
SEEDS=1-10; DAYS=60; JOBS=$(nproc); TMO=280; EXTRA=()
for a in "$@"; do case $a in
  --seeds=*) SEEDS=${a#*=};; --days=*) DAYS=${a#*=};; --jobs=*) JOBS=${a#*=};; --timeout=*) TMO=${a#*=};;
  --preset=*) ;; --ov=*|--nitrogen=*|--cap=*|--plate=*) EXTRA+=("$a");; *) echo "unknown $a" >&2; exit 2;; esac; done
FIRST=${SEEDS%-*}; LAST=${SEEDS#*-}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d); PIDS=()
cleanup() { for p in "${PIDS[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null; done; rm -rf "$T"; }
trap cleanup EXIT INT TERM
run() { timeout "$TMO" godot --headless --path "$ROOT" -s tools/factory_bot_report.gd -- --seeds=1 --first="$1" --days="$DAYS" --json "${EXTRA[@]}" >"$T/$1.out" 2>&1; }
for ((s=FIRST; s<=LAST; s++)); do
  while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do wait -n 2>/dev/null || true; done
  run "$s" & PIDS+=($!)
done
wait
python3 -I "$ROOT/tools/factory_eval_summary.py" "$T" "$FIRST" "$LAST"
