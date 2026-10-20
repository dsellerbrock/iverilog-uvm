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
assert set(stats["randomize_tiers"]) == {"T0", "T1", "T2", "T3", "T4"}
PY
"${TIMEOUT[@]}" "$IVERILOG" -g2017 -s main -o "$WORK/z3.vvp" "$HERE/randomize_z3.sv"
"${TIMEOUT[@]}" "$DEFAULT_VVP" -n "$WORK/z3.vvp" \
      >"$WORK/z3-default.out" 2>"$WORK/z3-default.err"
IVL_PERF_STATS=1 "${TIMEOUT[@]}" "$STATS_VVP" -n "$WORK/z3.vvp" \
      >"$WORK/z3-enabled.out" 2>"$WORK/z3-enabled.err"
cmp "$WORK/z3-default.out" "$WORK/z3-enabled.out"
grep -q '^VVP_PERF_STATS ' "$WORK/z3-enabled.err"
sed 's/^VVP_PERF_STATS //' "$WORK/z3-enabled.err" >"$WORK/z3-stats.json"
python3 - "$WORK/z3-stats.json" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as stream:
    stats = json.load(stream)
assert stats["z3"]["contexts"] > 0
assert stats["z3"]["checks"] > 0
assert stats["z3"]["model_evaluations"] > 0
assert stats["randomize_tiers"]["T3"] > 0
PY
"${TIMEOUT[@]}" "$IVERILOG" -g2017 -s main -o "$WORK/dv.vvp" \
      "$HERE/randomize_dv_txn.sv"
"${TIMEOUT[@]}" "$DEFAULT_VVP" -n "$WORK/dv.vvp" +runs=1 \
      >"$WORK/dv-default.out" 2>"$WORK/dv-default.err"
IVL_PERF_STATS=1 "${TIMEOUT[@]}" "$STATS_VVP" -n "$WORK/dv.vvp" +runs=1 \
      >"$WORK/dv-enabled.out" 2>"$WORK/dv-enabled.err"
cmp "$WORK/dv-default.out" "$WORK/dv-enabled.out"
grep '^VVP_PERF_STATS ' "$WORK/dv-enabled.err" | sed 's/^VVP_PERF_STATS //' \
      | python3 -c 'import json,sys; s=json.load(sys.stdin); assert s["randomize_tiers"]["T3"] == 0; assert s["randomize_tiers"]["T4"] == 1; assert s["z3"]["contexts"] == 1'
"${TIMEOUT[@]}" "$IVERILOG" -g2017 -s main -o "$WORK/order.vvp" \
      "$HERE/randomize_t4_order.sv"
IVL_PERF_STATS=1 "${TIMEOUT[@]}" "$STATS_VVP" -n "$WORK/order.vvp" \
      >"$WORK/order-enabled.out" 2>"$WORK/order-enabled.err"
grep '^VVP_PERF_STATS ' "$WORK/order-enabled.err" | sed 's/^VVP_PERF_STATS //' \
      | python3 -c 'import json,sys; s=json.load(sys.stdin); assert s["randomize_tiers"]["T3"] == 0; assert s["randomize_tiers"]["T4"] == 1; assert s["z3"]["contexts"] == 1'
"${TIMEOUT[@]}" "$IVERILOG" -g2017 -s main -o "$WORK/t0.vvp" \
      "$HERE/randomize_t0_disabled.sv"
"${TIMEOUT[@]}" "$DEFAULT_VVP" -n "$WORK/t0.vvp" \
      >"$WORK/t0-default.out" 2>"$WORK/t0-default.err"
"${TIMEOUT[@]}" "$STATS_VVP" -n "$WORK/t0.vvp" \
      >"$WORK/t0-disabled.out" 2>"$WORK/t0-disabled.err"
IVL_PERF_STATS=1 "${TIMEOUT[@]}" "$STATS_VVP" -n "$WORK/t0.vvp" \
      >"$WORK/t0-enabled.out" 2>"$WORK/t0-enabled.err"
cmp "$WORK/t0-default.out" "$WORK/t0-disabled.out"
cmp "$WORK/t0-default.out" "$WORK/t0-enabled.out"
grep '^VVP_PERF_STATS ' "$WORK/t0-enabled.err" | sed 's/^VVP_PERF_STATS //' \
      | python3 -c 'import json,sys; s=json.load(sys.stdin); assert s["randomize_tiers"]["T0"] == 400; assert s["randomize_tiers"]["T4"] == 0; assert s["z3"]["contexts"] == 0'
IVL_PERF_STATS=1 "${TIMEOUT[@]}" "$STATS_VVP" -n "$WORK/t0.vvp" +t4 \
      >"$WORK/t4-enabled.out" 2>"$WORK/t4-enabled.err"
grep '^VVP_PERF_STATS ' "$WORK/t4-enabled.err" | sed 's/^VVP_PERF_STATS //' \
      | python3 -c 'import json,sys; s=json.load(sys.stdin); assert s["randomize_tiers"]["T0"] == 0; assert s["randomize_tiers"]["T4"] == 400; assert s["z3"]["contexts"] == 400'
