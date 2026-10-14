#!/usr/bin/env bash
# Compare the default runtime with a --enable-perf-stats build.
set -euo pipefail
if (( $# != 3 )); then
      echo "usage: test_perf_stats.sh <iverilog> <default-vvp> <stats-vvp>" >&2
      exit 2
fi
IVERILOG=$1
DEFAULT_VVP=$2
STATS_VVP=$3
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
if command -v timeout >/dev/null 2>&1; then
      TIMEOUT=(timeout --kill-after=5s 60s)
elif command -v gtimeout >/dev/null 2>&1; then
      TIMEOUT=(gtimeout --kill-after=5s 60s)
else
      echo "GNU timeout is required to bound smoke-test processes" >&2
      exit 2
fi
"${TIMEOUT[@]}" "$IVERILOG" -g2012 -o "$WORK/smoke.vvp" "$HERE/perf_stats_smoke.v"
IVL_PERF_STATS=1 "${TIMEOUT[@]}" "$DEFAULT_VVP" -n "$WORK/smoke.vvp" \
      >"$WORK/default.out" 2>"$WORK/default.err"
"${TIMEOUT[@]}" "$STATS_VVP" -n "$WORK/smoke.vvp" \
      >"$WORK/disabled.out" 2>"$WORK/disabled.err"
cmp "$WORK/default.out" "$WORK/disabled.out"
cmp "$WORK/default.err" "$WORK/disabled.err"
IVL_PERF_STATS=1 "${TIMEOUT[@]}" "$STATS_VVP" -n "$WORK/smoke.vvp" \
      >"$WORK/enabled.out" 2>"$WORK/enabled.err"
cmp "$WORK/default.out" "$WORK/enabled.out"
grep -q '^VVP_PERF_STATS ' "$WORK/enabled.err"
sed 's/^VVP_PERF_STATS //' "$WORK/enabled.err" >"$WORK/stats.json"
python3 - "$WORK/stats.json" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as stream:
    stats = json.load(stream)
assert stats["events_by_region"]
assert stats["thread_creations"] >= 1
assert stats["opcode_histogram"]
assert stats["opcode_pairs"]
assert stats["functor_recv_vec4"]
assert "scheduler_time_list" in stats
assert set(stats["scheduler_time_list"]) == {
    "insertions", "total_steps", "max_steps"
}
assert "z3" in stats
PY
