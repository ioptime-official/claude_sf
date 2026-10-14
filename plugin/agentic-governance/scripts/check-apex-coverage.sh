#!/usr/bin/env bash
# Fails if Apex tests failed or test-run coverage is below the threshold.
# Usage: sf apex run test --test-level RunLocalTests --code-coverage --json ... > result.json
#        scripts/check-apex-coverage.sh result.json [min-percent]
set -euo pipefail
file="${1:?usage: $0 result.json [min-percent]}"
min="${2:-${COVERAGE_MIN:-85}}"

outcome="$(jq -r '.result.summary.outcome' "$file")"
failing="$(jq -r '.result.summary.failing' "$file")"
cov="$(jq -r '.result.summary.testRunCoverage // "0%"' "$file" | tr -d '%')"

echo "outcome=$outcome failing=$failing coverage=${cov}% (minimum ${min}%)"
[ "$failing" = "0" ] || { echo "FAIL: $failing Apex test(s) failing" >&2; exit 1; }
[ "$outcome" = "Passed" ] || { echo "FAIL: outcome is $outcome" >&2; exit 1; }
awk -v c="$cov" -v m="$min" 'BEGIN { exit !(c+0 >= m+0) }' \
  || { echo "FAIL: coverage ${cov}% is below ${min}%" >&2; exit 1; }
echo "OK"
