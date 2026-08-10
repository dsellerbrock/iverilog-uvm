#!/usr/bin/env bash
# Focused IEEE 1800-2017 16.4.2 Stage-2 gate: zero-actual passive user tasks.

set -u

DIR=$(cd "$(dirname "$0")" && pwd)
IVERILOG_BIN=${IVERILOG_BIN:-iverilog}
VVP_BIN=${VVP_BIN:-vvp}
SLANG_BIN=${SLANG_BIN:-slang}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail=0

compile_and_run_exact() {
    name=$1
    if ! "$IVERILOG_BIN" -g2012 -pfileline=1 \
            -o "$WORK/$name.vvp" "$DIR/$name.sv" \
            >"$WORK/$name.cc.out" 2>"$WORK/$name.cc.err"; then
        echo "FAIL: $name compile"
        sed -n '1,30p' "$WORK/$name.cc.err"
        fail=1
        return
    fi
    IVL_REGION_ASSERT=1 "$VVP_BIN" "$WORK/$name.vvp" \
            >"$WORK/$name.out" 2>"$WORK/$name.err"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "FAIL: $name runtime rc=$rc"
        fail=1
    fi
    if ! diff -u "$DIR/$name.gold" "$WORK/$name.out"; then
        echo "FAIL: $name output"
        fail=1
    fi
    if [ -s "$WORK/$name.err" ]; then
        echo "FAIL: $name unexpected stderr"
        sed -n '1,30p' "$WORK/$name.err"
        fail=1
    fi
}

compile_and_run_exact user_task

# Three source task actions are emitted: static, automatic, and the action
# that is later cancelled by re-executing its source assertion with null.
if [ -f "$WORK/user_task.vvp" ]; then
    task_keys=$(grep -c '%defer/final/taskkey' "$WORK/user_task.vvp" || true)
    if [ "$task_keys" -ne 3 ]; then
        echo "FAIL: expected three distinct task-key thunks, got $task_keys"
        fail=1
    fi
fi

# $error is a permitted passive body action. Its filename/line prefix is an
# implementation detail, so pin the message, lexical %m, value, and count.
if ! "$IVERILOG_BIN" -g2012 -o "$WORK/user_task_error.vvp" \
        "$DIR/user_task_error.sv" >"$WORK/error.cc.out" 2>"$WORK/error.cc.err"; then
    echo "FAIL: user_task_error compile"
    sed -n '1,30p' "$WORK/error.cc.err"
    fail=1
else
    IVL_REGION_ASSERT=1 "$VVP_BIN" "$WORK/user_task_error.vvp" \
        >"$WORK/error.out" 2>"$WORK/error.err"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "FAIL: user_task_error runtime rc=$rc"
        fail=1
    fi
    count=$(cat "$WORK/error.out" "$WORK/error.err" | \
        grep -c 'EXPECTED USER TASK deferred_final_user_task_error.report_error VALUE=23' || true)
    if [ "$count" -ne 1 ]; then
        echo "FAIL: expected exactly one deferred user-task error, got $count"
        cat "$WORK/error.out" "$WORK/error.err"
        fail=1
    fi
fi

# Every shape below is legal SystemVerilog but deliberately beyond this
# bounded slice. Icarus must issue exactly one loud NI; Slang must accept it.
for name in user_task_actual user_task_method user_task_nested \
            user_task_timed user_task_mutating user_task_side_effect_arg; do
    src="$DIR/$name.sv"
    if "$IVERILOG_BIN" -g2012 -o "$WORK/$name.vvp" "$src" \
            >"$WORK/$name.ivl.out" 2>"$WORK/$name.ivl.err"; then
        echo "FAIL: legal-NI $name unexpectedly compiled"
        fail=1
    else
        count=$(grep -Ec ':[0-9]+: (error|sorry):' \
            "$WORK/$name.ivl.err" || true)
        if [ "$count" -ne 1 ]; then
            echo "FAIL: legal-NI $name expected one diagnostic, got $count"
            sed -n '1,30p' "$WORK/$name.ivl.err"
            fail=1
        fi
    fi
    if ! "$SLANG_BIN" --std 1800-2017 --single-unit "$src" \
            >"$WORK/$name.slang.out" 2>"$WORK/$name.slang.err"; then
        echo "FAIL: Slang rejected legal-NI $name"
        sed -n '1,30p' "$WORK/$name.slang.err"
        fail=1
    fi
done

for name in user_task user_task_error; do
    if ! "$SLANG_BIN" --std 1800-2017 --single-unit "$DIR/$name.sv" \
            >"$WORK/$name.slang.out" 2>"$WORK/$name.slang.err"; then
        echo "FAIL: Slang rejected positive $name"
        sed -n '1,30p' "$WORK/$name.slang.err"
        fail=1
    fi
done

# A forged task-key may not turn arbitrary VVP code into Postponed work.
"$VVP_BIN" "$DIR/malformed_task_key.vvp" \
    >"$WORK/malformed.out" 2>"$WORK/malformed.err"
rc=$?
if [ "$rc" -ne 0 ]; then
    echo "FAIL: malformed task-key runtime rc=$rc"
    fail=1
fi
if ! diff -u "$DIR/malformed_task_key.stderr" "$WORK/malformed.err"; then
    echo "FAIL: malformed task-key diagnostic"
    fail=1
fi
if [ -s "$WORK/malformed.out" ]; then
    echo "FAIL: malformed task-key executed output"
    cat "$WORK/malformed.out"
    fail=1
fi

if [ "$fail" -eq 0 ]; then
    echo "deferred-final user-task gate: PASS"
    exit 0
fi
echo "deferred-final user-task gate: FAIL"
exit 1
