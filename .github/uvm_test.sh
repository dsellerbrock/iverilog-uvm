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
# sv*/DPI-export dispatchers against vvp.
#
# The umbrella is built with `iverilog-vpi` — the tree's own loadable-module
# driver — NOT a hand-rolled `g++ -shared -fPIC`. iverilog-vpi links with the
# platform-correct shared-library flag (configure's @shared@: -shared on Linux,
# `-shared -Wl,--enable-auto-image-base` on MinGW, `-bundle -undefined
# dynamic_lookup -flat_namespace` on macOS) AND against -lvpi/-lveriuser. The
# previous hand-rolled build had neither: with no -lvpi and no per-platform
# flag it happened to link on Linux (lazy binding of the undefined sv*/vpi_*
# symbols against vvp at load) but FAILED on Windows — a DLL must resolve all
# imports at link time — and on macOS, whose two-level namespace rejects the
# undefined imports. Both platforms therefore silently fell back to
# UVM_NO_DPI and never exercised the real DPI layer. If iverilog-vpi is
# missing or the build fails, fall back to UVM_NO_DPI so the suite still runs.
UVM_DPI_SO="/tmp/uvm_dpi_iv.vpi"
IVPI="$(dirname "$BIN")/iverilog-vpi"
NO_DPI_FLAG=""

# macOS has no top-level <malloc.h>; the vendored uvm_dpi.h includes it.
# Provide a shim that forwards to <stdlib.h> (which declares malloc/free/
# realloc) so the DPI umbrella compiles. Guarded to Darwin so Linux keeps
# using its real <malloc.h>. (iverilog-vpi handles the macOS namespace/link
# flags itself, so no -undefined/-flat_namespace is needed here anymore.)
DPI_COMPAT_INC=""
# Extra -L/-l passed through iverilog-vpi for platforms that must resolve every
# import at link time (Windows). Empty on Linux/macOS, which bind lazily.
DPI_EXTRA_LIB=""
case "$(uname -s)" in
    Darwin)
        # macOS has no top-level <malloc.h>; shim it to <stdlib.h>.
        mkdir -p /tmp/uvm_compat
        printf '#include <stdlib.h>\n' > /tmp/uvm_compat/malloc.h
        DPI_COMPAT_INC="-I/tmp/uvm_compat"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        # A Windows loadable module must resolve every external at link time,
        # unlike the lazy load-time binding on Linux/macOS. The umbrella pulls
        # in two symbol classes that no static lib provides:
        #   1. the sv* DPI-context API (svGetScopeFromName/svSetScope/...),
        #      which vvp.exe exports via vvp/vvp.def but ships in no archive;
        #   2. POSIX regex (regcomp/regexec/regfree/regerror).
        # Build a dedicated import library for ONLY the sv* exports (so it does
        # not collide with libvpi's own vpi_* definitions) and link it plus the
        # regex provider. DPI-export dispatchers generated per-design (e.g.
        # m__uvm_report_dpi) still resolve from the loaded image, which Windows
        # cannot bind here — that residue is reported by the build log below.
        if command -v dlltool >/dev/null 2>&1 && [ -f vvp/vvp.def ] ; then
            { printf 'EXPORTS\n'; grep -E '^sv[A-Za-z]' vvp/vvp.def; } > /tmp/uvm_sv.def
            if dlltool -d /tmp/uvm_sv.def -D vvp.exe -l /tmp/libuvmsv.a \
                       2>/tmp/uvm_dpi_implib.log ; then
                DPI_EXTRA_LIB="-L/tmp -luvmsv"
            fi
        fi
        DPI_EXTRA_LIB="$DPI_EXTRA_LIB -lregex"
        ;;
esac

# iverilog-vpi wants attached -I<path>; it appends .vpi to --name, compiles the
# umbrella object in the CWD (cleaned up below), and links per-platform. Any
# $DPI_EXTRA_LIB (-L/-l) is appended to the link for Windows symbol resolution.
if [ -x "$IVPI" ] && "$IVPI" --name=/tmp/uvm_dpi_iv -I"$UVM/dpi" $DPI_COMPAT_INC \
       uvm_dpi/uvm_dpi_iverilog.cc $DPI_EXTRA_LIB >/tmp/uvm_dpi_build.log 2>&1 ; then
    echo "UVM DPI library built ($UVM_DPI_SO via iverilog-vpi): running WITHOUT UVM_NO_DPI"
else
    echo "WARNING: UVM DPI library build failed; falling back to UVM_NO_DPI"
    sed 's/^/  /' /tmp/uvm_dpi_build.log
    NO_DPI_FLAG="-DUVM_NO_DPI"
    UVM_DPI_SO=""
fi
rm -f uvm_dpi_iverilog.o

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
    [ -f "$cfile" ] && srcs="$srcs $PWD/$cfile"
    [ -f "$stub" ]  && srcs="$srcs $stub"
    if [ -n "$srcs" ]; then
        # Build the per-test companion the same way as the umbrella — via
        # iverilog-vpi, so it links per-platform and resolves sv*/vpi_* against
        # vvp on macOS/Windows too. Run in /tmp (absolute source paths) so the
        # intermediate objects don't litter the repo checkout.
        ( cd /tmp && "$IVPI" --name="/tmp/uvm_dpi_${name}" $srcs ) \
            >"/tmp/uvm_dpi_${name}.buildlog" 2>&1
        dflags="$dflags -d /tmp/uvm_dpi_${name}.vpi"
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
# Restate the DPI mode next to the summary so it is always visible in a
# truncated CI log tail (the "UVM DPI library built ..." banner prints at the
# top of the step, thousands of lines up). On the secondary platforms this is
# the at-a-glance answer to "did we exercise real DPI or silently fall back?".
if [ -n "$UVM_DPI_SO" ]; then
    echo "DPI mode: REAL DPI umbrella loaded ($UVM_DPI_SO)"
else
    echo "DPI mode: UVM_NO_DPI FALLBACK — umbrella build failed"
    # Repeat the umbrella build error next to the summary so the exact link
    # residue (e.g. the DPI-export dispatchers Windows cannot bind) is visible
    # in a truncated CI log tail, not only at the top of the step.
    if [ -s /tmp/uvm_dpi_build.log ]; then
        echo "  --- umbrella build log (tail) ---"
        tail -12 /tmp/uvm_dpi_build.log | sed 's/^/  | /'
    fi
fi
echo "UVM regression: $PASS passed, $FAIL failed, $SKIP skipped"
[ $FAIL -eq 0 ]
