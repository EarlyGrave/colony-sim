#!/usr/bin/env bash
# N3: run ng_chain_report on 10 seeds as 5 parallel shards. Usage: tools/ng_chain_sweep.sh <outdir> <tag> [ov-json]
set -u
cd "$(dirname "$0")/.."
out="$1"; tag="$2"; ov="${3:-}"
mkdir -p "$out"
for f in 1 3 5 7 9; do
	if [ -n "$ov" ]; then
		godot --headless --path . -s tools/ng_chain_report.gd -- --seeds=2 --first=$f "--ov=$ov" > "$out/${tag}_$f.txt" 2>&1 &
	else
		godot --headless --path . -s tools/ng_chain_report.gd -- --seeds=2 --first=$f > "$out/${tag}_$f.txt" 2>&1 &
	fi
done
wait
grep -h "^seed" "$out/${tag}"_*.txt | sort -k2 -n
