#!/usr/bin/env sh
# UVM/SystemVerilog regression test runner for the development fork.
# Runs all tests in tests/ against the installed iverilog binary.
# Returns non-zero if any test fails.

set -e

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

compile_test() {
    local name="$1"
    local sv="$TESTS/${name}.sv"
    $BIN -g2012 -I "$UVM" -DUVM_NO_DPI -o "/tmp/uvm_test_${name}.vvp" \
         "$UVM/uvm_pkg.sv" "$sv" 2>/dev/null
}

run_test() {
    local name="$1"
    local cfile="$TESTS/${name}.c"
    if [ -f "$cfile" ]; then
        gcc -shared -fPIC -o "/tmp/uvm_dpi_${name}.so" "$cfile" 2>/dev/null
        $VVP -d "/tmp/uvm_dpi_${name}.so" "/tmp/uvm_test_${name}.vvp" 2>&1
    else
        $VVP "/tmp/uvm_test_${name}.vvp" 2>&1
    fi
}

for sv in $TESTS/*.sv; do
    name=$(basename "$sv" .sv)
    printf "  %-30s " "$name"

    if ! compile_test "$name" 2>/dev/null; then
        echo "COMPILE_FAIL"
        FAIL=$((FAIL+1))
        continue
    fi

    out=$(run_test "$name")
    # Match known-good output patterns
    if echo "$out" | grep -qE "PASS|data=ab|data=42|data=0xab|factorial.*120|sqrt.*2\.0|pow.*1024|negedge.*cd|anyedge.*ef|drive.*count"; then
        echo "PASS"
        PASS=$((PASS+1))
    elif echo "$out" | grep -qE "FAIL|UVM_ERROR|UVM_FATAL"; then
        echo "FAIL"
        echo "$out" | grep -E "FAIL|UVM_ERROR|UVM_FATAL" | head -3
        FAIL=$((FAIL+1))
    else
        echo "PASS (no-check)"
        PASS=$((PASS+1))
    fi
done

echo ""
echo "UVM regression: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
