#!/usr/bin/env bash
# UVM/SystemVerilog regression test runner for the development fork.
# Runs all tests in tests/ against the installed iverilog binary.
# Returns non-zero if any test fails.

BIN=$(which iverilog)
VVP=$(which vvp)
UVM="uvm-core/src"
TESTS="tests"

# Verify UVM sources are available
if [ ! -f "$UVM/uvm_pkg.sv" ]; then
    echo "ERROR: UVM sources not found at $UVM/uvm_pkg.sv"
    exit 1
fi

PASS=0
FAIL=0
SKIP=0

# Tests with known pre-existing issues (not regressions introduced by this fork).
# Phase 63b/skipped-tests cleanup (2026-05-02) — vif_smoke and vif_smoke_v2
# rewritten to use proper UVM sequence/sequencer API; plusargs test now
# receives required +args via PLUSARGS table below.
# reg_basic_test was previously skipped as "needs DPI HDL access"; that
# diagnosis was WRONG. The real failure was the NetEUFunc::dup_expr typing
# bug (string-returning get_rights() inside {"RW","WO"} compiled to a vec4
# compare and always failed, so the backdoor branch returned UVM_NOT_OK).
# Fixed 2026-07-18; a USER-DEFINED uvm_reg_backdoor works without DPI, so
# the test now runs. The uvm_hdl_* DPI backdoor remains future work (M10C).
KNOWN_FAIL=""

# Per-test plusargs.  Tests that need runtime args list them here so the
# vvp invocation can supply them.  Format: "<name>:+arg1+arg2 ...".
declare -A PLUSARGS=(
    [plusargs_class_string_test]="+MY_TESTNAME=hello +MY_SEED=42"
)

# Per-test extra iverilog compile flags.  Tests that need a compile
# option beyond the default (e.g. -gspecify to activate specify-block
# timing checks) list it here.  Format: "<name>=<flags>".
declare -A IVFLAGS=(
    [m13_timing_test]="-gspecify"
    [m13_specify_paths_test]="-gspecify"
    [m13b_timing_checks_test]="-gspecify"
)

compile_test() {
    local name="$1"
    local sv="$TESTS/${name}.sv"
    local xf="${IVFLAGS[$name]}"
    $BIN -g2012 $xf -I "$UVM" -DUVM_NO_DPI -o "/tmp/uvm_test_${name}.vvp" \
         "$UVM/uvm_pkg.sv" "$sv" 2>/dev/null
}

run_test() {
    local name="$1"
    local cfile="$TESTS/${name}.c"
    local extra="${PLUSARGS[$name]}"
    if [ -f "$cfile" ]; then
        gcc -shared -fPIC -o "/tmp/uvm_dpi_${name}.so" "$cfile" 2>/dev/null
        timeout 60 $VVP -d "/tmp/uvm_dpi_${name}.so" "/tmp/uvm_test_${name}.vvp" $extra 2>&1 || true
    else
        timeout 60 $VVP "/tmp/uvm_test_${name}.vvp" $extra 2>&1 || true
    fi
}

for sv in $TESTS/*.sv; do
    name=$(basename "$sv" .sv)
    printf "  %-30s " "$name"

    # Skip known pre-existing failures
    if echo "$KNOWN_FAIL" | grep -qw "$name"; then
        echo "SKIP (known)"
        SKIP=$((SKIP+1))
        continue
    fi

    if ! compile_test "$name" 2>/dev/null; then
        echo "COMPILE_FAIL"
        FAIL=$((FAIL+1))
        continue
    fi

    out=$(run_test "$name")
    # Failure evidence is checked BEFORE any PASS marker, so a test that
    # prints "PASS" for one sub-check cannot mask a real error emitted
    # elsewhere in the same run (this previously hid reg_basic_test, whose
    # backdoor register access fires two UVM_ERRORs while a later mirror
    # check prints PASS). Failure evidence is any of:
    #   - a real UVM error/fatal REPORT line:  "UVM_ERROR <file> @ <t>: ..."
    #   - a non-zero UVM summary COUNT:        "UVM_ERROR :   N"  (N>0)
    #   - an explicit FAIL, or a vvp image rejection (Invalid opcode /
    #     Program not runnable = the test never ran).
    FAIL_RE='UVM_(ERROR|FATAL) .*@|UVM_(ERROR|FATAL) +:? +[1-9]|(^|[^A-Za-z_])FAIL|Invalid opcode|Program not runnable'
    PASS_RE='PASS|data=ab|data=42|data=0xab|factorial.*120|sqrt.*2\.0|pow.*1024|negedge.*cd|anyedge.*ef|drive.*count'
    if echo "$out" | grep -qE "$FAIL_RE"; then
        echo "FAIL"
        echo "$out" | grep -E "$FAIL_RE" | head -3
        FAIL=$((FAIL+1))
    elif echo "$out" | grep -qE "$PASS_RE"; then
        echo "PASS"
        PASS=$((PASS+1))
    else
        # No PASS marker AND no error: the test produced nothing we can
        # verify. A silent no-output run must NOT score as a pass — that
        # is exactly how a broken test hides. Count it as a failure.
        echo "FAIL (no-check: no PASS marker and no error evidence)"
        FAIL=$((FAIL+1))
    fi
done

echo ""
echo "UVM regression: $PASS passed, $FAIL failed, $SKIP skipped"
[ $FAIL -eq 0 ]
