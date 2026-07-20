#!/usr/bin/env bash
# UVM/SystemVerilog regression test runner for the development fork.
# Runs all tests in tests/ against the installed iverilog binary.
# Returns non-zero if any test fails.

BIN=$(which iverilog)
VVP=$(which vvp)
UVM="uvm-core/src"
TESTS="tests"

# Per-test run timeout wrapper. GNU coreutils `timeout` is present on Linux
# CI but NOT on the base macOS runner (it ships neither `timeout` nor
# `gtimeout`, and the brew step installs only bison/z3/libffi). Without this
# resolution, `timeout 60 vvp ...` failed with "command not found" for EVERY
# test on macOS, so every vvp run produced no output and scored as a no-check
# failure — the whole macOS UVM suite read as 0 passed while looking green
# under continue-on-error. Fall back to running vvp directly (no wrapper) when
# no timeout tool exists.
if command -v timeout >/dev/null 2>&1 ; then
    TIMEOUT="timeout 60"
elif command -v gtimeout >/dev/null 2>&1 ; then
    TIMEOUT="gtimeout 60"
else
    TIMEOUT=""
fi

# Verify UVM sources are available
if [ ! -f "$UVM/uvm_pkg.sv" ]; then
    echo "ERROR: UVM sources not found at $UVM/uvm_pkg.sv"
    exit 1
fi

PASS=0
FAIL=0
SKIP=0

# Build the UVM DPI library so the suite exercises the real DPI layer
# (regex + command-line + HDL backdoor) instead of the UVM_NO_DPI native
# fallbacks. The fork-owned umbrella (uvm_dpi/uvm_dpi_iverilog.cc) combines
# the vendored UVM DPI sources with an Icarus HDL backend and resolves the
# sv*/DPI-export dispatchers against vvp. If the build fails (e.g. no g++ or
# headers), fall back to UVM_NO_DPI so the rest of the suite still runs.
UVM_DPI_SO="/tmp/uvm_dpi_iv.so"
IVL_INC="$(dirname "$(dirname "$(command -v iverilog)")")/include/iverilog"
NO_DPI_FLAG=""

# macOS has no top-level <malloc.h>; the vendored uvm_dpi.h includes it.
# Provide a shim that forwards to <stdlib.h> (which declares malloc/free/
# realloc) so the DPI umbrella compiles. Guarded to Darwin so Linux keeps
# using its real <malloc.h>.
#
# macOS also uses a two-level namespace by default: symbols a bundle
# references (the sv*/DPI-export dispatchers this umbrella calls) must be
# resolvable at LINK time or the .dylib is rejected, but those live in the
# vvp executable, not any library we can name here. -undefined dynamic_lookup
# defers them to load time so vvp satisfies them. Linux resolves lazily by
# default, so this flag is Darwin-only.
DPI_COMPAT_INC=""
DPI_LDFLAGS=""
if [ "$(uname)" = "Darwin" ]; then
    mkdir -p /tmp/uvm_compat
    printf '#include <stdlib.h>\n' > /tmp/uvm_compat/malloc.h
    DPI_COMPAT_INC="-I/tmp/uvm_compat"
    DPI_LDFLAGS="-undefined dynamic_lookup"
fi

if g++ -shared -fPIC -I"$IVL_INC" -I "$UVM/dpi" $DPI_COMPAT_INC $DPI_LDFLAGS \
       -o "$UVM_DPI_SO" uvm_dpi/uvm_dpi_iverilog.cc 2>/tmp/uvm_dpi_build.log ; then
    echo "UVM DPI library built ($UVM_DPI_SO): running WITHOUT UVM_NO_DPI"
else
    echo "WARNING: UVM DPI library build failed; falling back to UVM_NO_DPI"
    sed 's/^/  /' /tmp/uvm_dpi_build.log
    NO_DPI_FLAG="-DUVM_NO_DPI"
    UVM_DPI_SO=""
fi

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

# Per-test plusargs and extra iverilog compile flags. Kept as plain case
# functions rather than `declare -A` associative arrays so the harness runs
# under the bash 3.2 that ships on macOS (associative arrays need bash 4+).
plusargs_for() {
    case "$1" in
        plusargs_class_string_test) echo "+MY_TESTNAME=hello +MY_SEED=42" ;;
        *) echo "" ;;
    esac
}

ivflags_for() {
    case "$1" in
        m13_timing_test|m13_specify_paths_test|m13b_timing_checks_test) echo "-gspecify" ;;
        *) echo "" ;;
    esac
}

compile_test() {
    local name="$1"
    local sv="$TESTS/${name}.sv"
    local xf; xf="$(ivflags_for "$name")"
    $BIN -g2012 $xf -I "$UVM" $NO_DPI_FLAG -o "/tmp/uvm_test_${name}.vvp" \
         "$UVM/uvm_pkg.sv" "$sv"
}

run_test() {
    local name="$1"
    local cfile="$TESTS/${name}.c"
    local extra; extra="$(plusargs_for "$name")"
    # DPI export (35.5): iverilog emits a companion C stub next to the .vvp
    # output providing the exported C symbols. Compile it into the DPI object
    # alongside the user's C so the exports link.
    local stub="/tmp/uvm_test_${name}.dpiexport.c"
    # Always load the UVM DPI library when present; a per-test C companion
    # and/or the generated DPI-export stub go into a second DPI object.
    local dflags=""
    [ -n "$UVM_DPI_SO" ] && dflags="-d $UVM_DPI_SO"
    local srcs=""
    [ -f "$cfile" ] && srcs="$srcs $cfile"
    [ -f "$stub" ]  && srcs="$srcs $stub"
    if [ -n "$srcs" ]; then
        gcc -shared -fPIC $DPI_LDFLAGS -o "/tmp/uvm_dpi_${name}.so" $srcs \
            2>"/tmp/uvm_dpi_${name}.buildlog"
        dflags="$dflags -d /tmp/uvm_dpi_${name}.so"
    fi
    $TIMEOUT $VVP $dflags "/tmp/uvm_test_${name}.vvp" $extra 2>&1 || true
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

    if ! compile_test "$name" 2>"/tmp/uvm_compile_${name}.log"; then
        echo "COMPILE_FAIL"
        sed 's/^/      | /' "/tmp/uvm_compile_${name}.log" | head -6
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
        #
        # Surface whatever vvp actually emitted (stderr is folded into $out
        # via run_test's 2>&1) plus any per-test DPI-companion build errors,
        # so a platform where vvp silently produces nothing (e.g. a DPI
        # library that fails to load) shows its real cause instead of the
        # opaque "no error evidence". Bounded so a runaway test can't flood
        # the log.
        echo "FAIL (no-check: no PASS marker and no error evidence)"
        if [ -n "$out" ]; then
            printf '%s\n' "$out" | sed 's/^/      > /' | head -8
        else
            echo "      > (vvp produced no output at all)"
        fi
        if [ -s "/tmp/uvm_dpi_${name}.buildlog" ]; then
            echo "      > per-test DPI build:"
            sed 's/^/      | /' "/tmp/uvm_dpi_${name}.buildlog" | head -4
        fi
        FAIL=$((FAIL+1))
    fi
done

echo ""
echo "UVM regression: $PASS passed, $FAIL failed, $SKIP skipped"
[ $FAIL -eq 0 ]
