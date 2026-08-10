#!/usr/bin/env bash
# Active boundary gate for IEEE 1800-2017 16.4 final-deferred assertions.
# Supported behavior is checked by both ivtest harnesses. This script adds:
#   * an explicit scheduler-region oracle (NBA < Observed < Reactive < ROSync);
#   * Slang polarity for the two genuinely illegal action shapes; and
#   * active legal-but-not-yet-supported probes. Those probes must remain a
#     loud Icarus rejection AND a Slang acceptance until their support lands.

set -u

DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$DIR/../.." && pwd)
IVERILOG_BIN=${IVERILOG_BIN:-iverilog}
VVP_BIN=${VVP_BIN:-vvp}
SLANG_BIN=${SLANG_BIN:-slang}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail=0

# Final must be the Postponed event after every stabilizing region, and the
# synchronous action thread may create no forbidden ROSync transition.
if ! "$IVERILOG_BIN" -g2012 -o "$WORK/order.vvp" \
        "$ROOT/ivtest/ivltests/sv_deferred_final_order0.v" \
        >"$WORK/order.cc" 2>&1; then
    echo "FAIL: region-order compile"
    sed -n '1,20p' "$WORK/order.cc"
    fail=1
else
    IVL_REGION_TRACE=1 IVL_REGION_ASSERT=1 \
        "$VVP_BIN" "$WORK/order.vvp" >"$WORK/order.out" 2>"$WORK/order.trace"
    run_rc=$?
    if [ "$run_rc" -ne 0 ]; then
        echo "FAIL: region-order runtime rc=$run_rc"
        fail=1
    fi
    if ! diff -u "$ROOT/ivtest/gold/sv_deferred_final_order0-vvp-stdout.gold" \
            "$WORK/order.out"; then
        echo "FAIL: region-order output"
        fail=1
    fi

    line_of() {
        grep -n -m1 "$1" "$WORK/order.trace" | cut -d: -f1
    }
    p_nba=$(line_of 'REGION @ 0 ps NBA:')
    p_obs=$(line_of 'REGION @ 0 ps Observed:')
    p_react=$(line_of 'REGION @ 0 ps Reactive:')
    p_final=$(line_of 'REGION @ 0 ps ROSync:.*final_deferred_assert_mature_event_s')
    if [ -z "$p_nba" ] || [ -z "$p_obs" ] || [ -z "$p_react" ] || \
       [ -z "$p_final" ] || [ "$p_nba" -ge "$p_obs" ] || \
       [ "$p_obs" -ge "$p_react" ] || [ "$p_react" -ge "$p_final" ]; then
        echo "FAIL: expected NBA < Observed < Reactive < final ROSync; got ${p_nba:-?} ${p_obs:-?} ${p_react:-?} ${p_final:-?}"
        fail=1
    else
        echo "PASS region order: NBA($p_nba) < Observed($p_obs) < Reactive($p_react) < final ROSync($p_final)"
    fi
    if grep -q 'SCHEDULER ERROR' "$WORK/order.trace"; then
        echo "FAIL: final action created an illegal Postponed transition"
        fail=1
    fi
fi

# Slang and the LRM reject these action-block shapes; Icarus must too.
for name in sv_deferred_final_block_fail sv_deferred_final_void_cast_fail; do
    src="$ROOT/ivtest/ivltests/$name.v"
    if "$SLANG_BIN" --std 1800-2017 --single-unit "$src" \
            >"$WORK/$name.slang.out" 2>"$WORK/$name.slang.err"; then
        echo "FAIL: Slang unexpectedly accepted illegal $name"
        fail=1
    else
        echo "PASS illegal polarity: $name rejected by Slang"
    fi
done

# These are legal programs. They are kept out of CE manifests so a temporary
# implementation boundary never becomes an expected language rejection.
for name in dynamic_args user_task error_args cover_final in_final_procedure; do
    src="$DIR/$name.sv"
    if "$IVERILOG_BIN" -g2012 -o "$WORK/$name.vvp" "$src" \
            >"$WORK/$name.ivl.out" 2>"$WORK/$name.ivl.err"; then
        echo "FAIL: blocker $name unexpectedly compiled; promote it to a positive test"
        fail=1
        continue
    fi
    count=$(grep -Ec '(^|: )(error|sorry):' "$WORK/$name.ivl.err" || true)
    if [ "$count" -ne 1 ]; then
        echo "FAIL: blocker $name expected exactly one loud diagnostic, got $count"
        sed -n '1,20p' "$WORK/$name.ivl.err"
        fail=1
        continue
    fi
    if ! "$SLANG_BIN" --std 1800-2017 --single-unit "$src" \
            >"$WORK/$name.slang.out" 2>"$WORK/$name.slang.err"; then
        echo "FAIL: Slang rejected legal blocker $name"
        sed -n '1,20p' "$WORK/$name.slang.err"
        fail=1
        continue
    fi
    echo "PASS active blocker: $name (Icarus loud reject, Slang accept)"
done

if [ "$fail" -eq 0 ]; then
    echo "deferred-final boundary gate: PASS"
    exit 0
fi
echo "deferred-final boundary gate: FAIL"
exit 1
