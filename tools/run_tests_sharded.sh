#!/usr/bin/env bash
# Runs the whole test suite as N parallel Godot processes (default 4). Exit code 1 if any shard fails.
# Usage: tools/run_tests_sharded.sh [shards] [extra runner args, e.g. --filter=test_map]
# Single-process equivalent: godot --headless --path . res://tests/run_tests.tscn
set -u
N="${1:-4}"; shift || true
export PERF_SKIP_WALL=1  # timings are meaningless under parallel load; run test_perf_budget single-process
GODOT="${GODOT:-godot}"
OUT="$(mktemp -d)"
pids=()
for i in $(seq 1 "$N"); do
	"$GODOT" --headless --path . res://tests/run_tests.tscn -- --shard="$i/$N" "$@" > "$OUT/shard$i.log" 2>&1 &
	pids+=($!)
done
rc=0
for p in "${pids[@]}"; do wait "$p" || rc=1; done
for i in $(seq 1 "$N"); do
	grep -E "^\s+FAIL|^        - |^Tests:" "$OUT/shard$i.log" | sed "s/^/[shard $i] /"
done
passed=$(cat "$OUT"/shard*.log | grep -oE "Tests: [0-9]+ passed" | awk '{s+=$2} END{print s+0}')
failed=$(cat "$OUT"/shard*.log | grep -oE ", [0-9]+ failed" | awk '{s+=$2} END{print s+0}')
echo "TOTAL: $passed passed, $failed failed (logs: $OUT)"
[ "$failed" -eq 0 ] && [ "$rc" -eq 0 ] || exit 1
