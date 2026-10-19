#!/usr/bin/env bash
# Quick check after merging a branch into the dev branch: runs only the test files that
# mention a changed script/data file, plus the always-on core (goldens, contract, phone layout).
# The full suite (tools/run_tests_sharded.sh) still runs once before every merge to main.
# Usage: tools/run_tests_quick.sh [base-ref]   (default base: origin/main)
set -u
BASE="${1:-origin/main}"
cd "$(dirname "$0")/.."
tests=(test_golden test_contract_doc test_phone_layout test_qa_commands)
while IFS= read -r f; do
	[ -z "$f" ] && continue
	stem="$(basename "$f")"; stem="${stem%.*}"
	case "$f" in
		tests/test_*.gd) tests+=("$stem"); continue ;;
		*.gd|*.json) ;;
		*) continue ;;
	esac
	while IFS= read -r t; do
		tests+=("$(basename "$t" .gd)")
	done < <(grep -l -F "$stem" tests/test_*.gd 2>/dev/null)
done < <(git diff --name-only "$BASE"...HEAD)
filter="$(printf '%s\n' "${tests[@]}" | sort -u | paste -sd, -)"
echo "quick tests: $(printf '%s\n' "${tests[@]}" | sort -u | wc -l) files"
exec bash tools/run_tests_sharded.sh 4 --filter="$filter"
