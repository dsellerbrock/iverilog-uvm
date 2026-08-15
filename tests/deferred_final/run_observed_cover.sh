#!/usr/bin/env bash
# Focused IEEE 1800-2017 16.4 gate for observed-deferred argument capture
# and deferred immediate cover statements.

set -u

DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$DIR/../.." && pwd)
IVERILOG_BIN=${IVERILOG_BIN:-iverilog}
VVP_BIN=${VVP_BIN:-vvp}
SLANG_BIN=${SLANG_BIN:-slang}
VPI_MODULE_DIR=${VPI_MODULE_DIR:-$ROOT/local-install/lib/ivl}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail=0

for name in sv_deferred_observed_args0 sv_deferred_cover_actions0; do
    src="$ROOT/ivtest/ivltests/$name.v"
    if ! "$IVERILOG_BIN" -g2012 -o "$WORK/$name.vvp" "$src" \
            >"$WORK/$name.cc.out" 2>"$WORK/$name.cc.err"; then
        echo "FAIL: $name compile"
        sed -n '1,30p' "$WORK/$name.cc.err"
        fail=1
        continue
    fi
    IVL_REGION_ASSERT=1 "$VVP_BIN" "$WORK/$name.vvp" \
        >"$WORK/$name.out" 2>"$WORK/$name.err"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "FAIL: $name runtime rc=$rc"
        fail=1
    fi
    if ! diff -u "$ROOT/ivtest/gold/$name-vvp-stdout.gold" \
            "$WORK/$name.out"; then
        echo "FAIL: $name output"
        fail=1
    fi
    if [ -s "$WORK/$name.err" ]; then
        echo "FAIL: $name unexpected stderr"
        sed -n '1,30p' "$WORK/$name.err"
        fail=1
    fi
    if ! "$SLANG_BIN" --std 1800-2017 --single-unit "$src" \
            >"$WORK/$name.slang.out" 2>"$WORK/$name.slang.err"; then
        echo "FAIL: Slang rejected positive $name"
        sed -n '1,30p' "$WORK/$name.slang.err"
        fail=1
    fi
done

# A deferred $error uses the same immediate positional-value capture, while
# its report intentionally appears in the VVP output stream.
name=sv_deferred_observed_error_args0
src="$ROOT/ivtest/ivltests/$name.v"
if ! (cd "$ROOT/ivtest" && "$IVERILOG_BIN" -g2012 \
        -o "$WORK/$name.vvp" "ivltests/$name.v") \
        >"$WORK/$name.cc.out" 2>"$WORK/$name.cc.err"; then
    echo "FAIL: $name compile"
    sed -n '1,30p' "$WORK/$name.cc.err"
    fail=1
else
    IVL_REGION_ASSERT=1 "$VVP_BIN" "$WORK/$name.vvp" \
        >"$WORK/$name.out" 2>"$WORK/$name.err"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "FAIL: $name runtime rc=$rc"
        fail=1
    fi
    if ! diff -u "$ROOT/ivtest/gold/$name-vvp-stdout.gold" \
            "$WORK/$name.out"; then
        echo "FAIL: $name output"
        fail=1
    fi
    if [ -s "$WORK/$name.err" ]; then
        echo "FAIL: $name unexpected stderr"
        sed -n '1,30p' "$WORK/$name.err"
        fail=1
    fi
fi
if ! "$SLANG_BIN" --std 1800-2017 --single-unit "$src" \
        >"$WORK/$name.slang.out" 2>"$WORK/$name.slang.err"; then
    echo "FAIL: Slang rejected positive $name"
    sed -n '1,30p' "$WORK/$name.slang.err"
    fail=1
fi

# Turning assertions off must replace every direct procedural assertion form
# with a real empty statement; a null process body used to crash elaboration.
name=sv_deferred_cover_disabled0
src="$ROOT/ivtest/ivltests/$name.v"
if ! "$IVERILOG_BIN" -g2012 -gno-assertions \
        -o "$WORK/$name.vvp" "$src" \
        >"$WORK/$name.cc.out" 2>"$WORK/$name.cc.err"; then
    echo "FAIL: $name compile"
    sed -n '1,30p' "$WORK/$name.cc.err"
    fail=1
else
    "$VVP_BIN" "$WORK/$name.vvp" \
        >"$WORK/$name.out" 2>"$WORK/$name.err"
    rc=$?
    if [ "$rc" -ne 0 ] || [ -s "$WORK/$name.out" ] \
            || [ -s "$WORK/$name.err" ]; then
        echo "FAIL: $name expected a silent disabled run, rc=$rc"
        fail=1
    fi
fi
if ! "$SLANG_BIN" --std 1800-2017 --single-unit "$src" \
        >"$WORK/$name.slang.out" 2>"$WORK/$name.slang.err"; then
    echo "FAIL: Slang rejected labeled assertion-control source $name"
    sed -n '1,30p' "$WORK/$name.slang.err"
    fail=1
fi

# The exact sv-tests cover spellings must remain clean compile positives.
for name in cover_final cover0; do
    src="$DIR/$name.sv"
    if ! "$IVERILOG_BIN" -g2012 -o "$WORK/$name.vvp" "$src" \
            >"$WORK/$name.cc.out" 2>"$WORK/$name.cc.err"; then
        echo "FAIL: $name compile"
        sed -n '1,30p' "$WORK/$name.cc.err"
        fail=1
    fi
done

# These legal action shapes remain outside the bounded system-task slice.
# Keep every boundary loud and pin both its diagnostic and Slang polarity.
for spec in \
    "observed_user_task_actual|The fail action of a deferred immediate assertion is not supported yet." \
    "observed_ref_action|The fail action of a deferred immediate assertion is not supported yet." \
    "observed_fixed_array_action|deferred \$display argument 2 has an unsupported capture shape; no argument was evaluated and no action was emitted."
do
    name=${spec%%|*}
    expected=${spec#*|}
    src="$DIR/$name.sv"
    if "$IVERILOG_BIN" -g2012 -o "$WORK/$name.vvp" "$src" \
            >"$WORK/$name.ivl.out" 2>"$WORK/$name.ivl.err"; then
        echo "FAIL: $name boundary unexpectedly compiled"
        fail=1
    else
        count=$(grep -Ec ':[0-9]+: (error|sorry):' \
            "$WORK/$name.ivl.err" || true)
        if [ "$count" -ne 1 ] \
                || ! grep -Fq "$expected" "$WORK/$name.ivl.err"; then
            echo "FAIL: $name expected one focused diagnostic"
            sed -n '1,30p' "$WORK/$name.ivl.err"
            fail=1
        fi
    fi
    if ! "$SLANG_BIN" --std 1800-2017 --single-unit "$src" \
            >"$WORK/$name.slang.out" 2>"$WORK/$name.slang.err"; then
        echo "FAIL: Slang rejected legal $name boundary"
        sed -n '1,30p' "$WORK/$name.slang.err"
        fail=1
    fi
done

# A statement block is not a deferred action call in either implementation.
name=sv_deferred_flush1
src="$ROOT/ivtest/ivltests/$name.v"
if "$IVERILOG_BIN" -g2012 -o "$WORK/$name.vvp" "$src" \
        >"$WORK/$name.ivl.out" 2>"$WORK/$name.ivl.err"; then
    echo "FAIL: $name unexpectedly compiled"
    fail=1
else
    count=$(grep -Ec ':[0-9]+: (error|sorry):' "$WORK/$name.ivl.err" || true)
    if [ "$count" -ne 1 ] \
            || ! grep -Fq "must be a single subroutine call or a null statement" \
                "$WORK/$name.ivl.err"; then
        echo "FAIL: $name expected one focused Icarus diagnostic"
        sed -n '1,30p' "$WORK/$name.ivl.err"
        fail=1
    fi
fi
if "$SLANG_BIN" --std 1800-2017 --single-unit "$src" \
        >"$WORK/$name.slang.out" 2>"$WORK/$name.slang.err"; then
    echo "FAIL: Slang unexpectedly accepted $name"
    fail=1
else
    count=$(grep -c ': error:' "$WORK/$name.slang.err" || true)
    if [ "$count" -ne 1 ] \
            || ! grep -Fq "deferred assertion action must be a subroutine call" \
                "$WORK/$name.slang.err"; then
        echo "FAIL: $name expected one focused Slang diagnostic"
        sed -n '1,30p' "$WORK/$name.slang.err"
        fail=1
    fi
fi

# A void cast is not a deferred action call in either implementation.
name=sv_deferred_void_cast_action_fail
src="$ROOT/ivtest/ivltests/$name.v"
if "$IVERILOG_BIN" -g2012 -o "$WORK/$name.vvp" "$src" \
        >"$WORK/$name.ivl.out" 2>"$WORK/$name.ivl.err"; then
    echo "FAIL: $name unexpectedly compiled"
    fail=1
else
    count=$(grep -Ec ':[0-9]+: (error|sorry):' "$WORK/$name.ivl.err" || true)
    if [ "$count" -ne 1 ] \
            || ! grep -Fq "must be a direct subroutine call; a void cast is not an action call" \
                "$WORK/$name.ivl.err"; then
        echo "FAIL: $name expected one focused Icarus diagnostic"
        sed -n '1,30p' "$WORK/$name.ivl.err"
        fail=1
    fi
fi
if "$SLANG_BIN" --std 1800-2017 --single-unit "$src" \
        >"$WORK/$name.slang.out" 2>"$WORK/$name.slang.err"; then
    echo "FAIL: Slang unexpectedly accepted $name"
    fail=1
else
    count=$(grep -c ': error:' "$WORK/$name.slang.err" || true)
    if [ "$count" -ne 1 ] \
            || ! grep -Fq "void casting is only allowed for function calls" \
                "$WORK/$name.slang.err"; then
        echo "FAIL: $name expected one focused Slang diagnostic"
        sed -n '1,30p' "$WORK/$name.slang.err"
        fail=1
    fi
fi

# Forged stack metadata must be rejected before consuming source operands.
if [ ! -f "$VPI_MODULE_DIR/system.vpi" ]; then
    echo "FAIL: system.vpi is not installed in: $VPI_MODULE_DIR"
    fail=1
fi
"$VVP_BIN" -M "$VPI_MODULE_DIR" -m system \
    "$DIR/malformed_observed_args.vvp" \
    >"$WORK/malformed.out" 2>"$WORK/malformed.err"
rc=$?
if [ "$rc" -ne 0 ]; then
    echo "FAIL: malformed observed action runtime rc=$rc"
    fail=1
fi
if ! diff -u "$DIR/malformed_observed_args.stderr" "$WORK/malformed.err"; then
    echo "FAIL: malformed observed action diagnostic"
    fail=1
fi
if ! diff -u "$DIR/malformed_observed_args.stdout" \
        "$WORK/malformed.out"; then
    echo "FAIL: malformed observed action consumed the source operand"
    fail=1
fi

if [ "$fail" -eq 0 ]; then
    echo "deferred observed/cover gate: PASS"
    exit 0
fi
echo "deferred observed/cover gate: FAIL"
exit 1
