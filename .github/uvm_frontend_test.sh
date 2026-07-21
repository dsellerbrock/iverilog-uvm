#!/usr/bin/env bash
#
# End-to-end regression for the supported UVM front end (`iverilog -uvm').
#
# Unlike .github/uvm_test.sh (which sweeps tests/*.sv through the low-level
# manual flow), this script validates the *simplified* user experience: that
# a freshly installed toolchain runs a real, DPI-enabled UVM test with no
# user-specified UVM paths, module paths, or DPI libraries — from an
# arbitrary working directory.
#
# It performs its own staged install into a temporary prefix and then hides
# the build's compiled-in install root, so the staged toolchain must locate
# all of its resources by executable-relative discovery. That makes this one
# run cover three of the required scenarios at once: a custom install prefix,
# a relocated installation, and a working directory outside the source tree.
# Run after `make`.
#
# Exits non-zero if any scenario fails.

set -u

SRCROOT="$(cd "$(dirname "$0")/.." && pwd)"
PFX="$(mktemp -d 2>/dev/null || echo /tmp/ivl_fe_pfx.$$)"
WORK="$(mktemp -d 2>/dev/null || echo /tmp/ivl_fe_work.$$)"
FAIL=0
HIDDEN=""

# Per-run timeout wrapper (absent on the base macOS runner; fall back to none).
if command -v timeout >/dev/null 2>&1 ; then TO="timeout 120"
elif command -v gtimeout >/dev/null 2>&1 ; then TO="gtimeout 120"
else TO="" ; fi

say()  { printf '\n=== %s ===\n' "$1" ; }
pass() { printf '  PASS: %s\n' "$1" ; }
fail() { printf '  FAIL: %s\n' "$1" ; FAIL=1 ; }

# Restore the hidden compiled-in root no matter how we exit.
cleanup() {
    [ -n "$HIDDEN" ] && [ -d "$HIDDEN" ] && mv "$HIDDEN" "${HIDDEN%.reloc-hidden}" 2>/dev/null || true
    rm -rf "$PFX" "$WORK"
}
trap cleanup EXIT

# --------------------------------------------------------------------------
say "Staged install into custom prefix: $PFX"
if ! make -C "$SRCROOT" install prefix="$PFX" >"$WORK/install.log" 2>&1 ; then
    echo "ERROR: staged install failed:"
    tail -30 "$WORK/install.log"
    exit 1
fi

IVERILOG="$PFX/bin/iverilog"
VVP="$PFX/bin/vvp"

if [ ! -x "$IVERILOG" ] || [ ! -x "$VVP" ]; then
    echo "ERROR: toolchain not installed under $PFX"
    exit 1
fi

# The installer must have produced the staged UVM resources (this validates
# the install rules on every platform, independent of discovery below).
[ -f "$PFX/lib/ivl/uvm/src/uvm_pkg.sv" ] && pass "installer staged UVM sources" \
    || { fail "installer did not stage UVM sources"; echo "  (is the uvm-core submodule checked out?)"; }
[ -f "$PFX/lib/ivl/uvm_dpi.vpi" ] && pass "installer staged UVM DPI runtime" \
    || fail "installer did not stage the UVM DPI runtime module"

# Force executable-relative discovery when possible: temporarily move the
# build's compiled-in install root (<configured-prefix>/lib/ivl) aside so the
# staged $PFX toolchain cannot fall back to it. This exercises the relocation
# + custom-prefix paths. When the compiled-in root is not writable (e.g. a
# root-owned system install under an unprivileged CI runner), we skip hiding
# it and the staged toolchain resolves to that root instead — still a valid
# installed-toolchain test, just not a relocated one. The root is restored by
# cleanup().
P0="$(sed -n 's/^prefix *= *//p' "$SRCROOT/Makefile" 2>/dev/null | head -1)"
P0BASE="$P0/lib/ivl"
if [ -n "$P0" ] && [ -d "$P0BASE" ] && [ "$P0BASE" != "$PFX/lib/ivl" ]; then
    if mv "$P0BASE" "$P0BASE.reloc-hidden" 2>/dev/null ; then
        HIDDEN="$P0BASE.reloc-hidden"
        say "Compiled-in root $P0BASE hidden; \$PFX must self-locate (relocation test)"
    fi
fi

# Determine the install root the staged toolchain will ACTUALLY resolve to,
# so the scenarios (and the S6 file surgery) target the right tree.
if [ -n "$HIDDEN" ]; then
    BASE="$PFX/lib/ivl"          # compiled-in hidden -> exe-relative to $PFX
elif [ -n "$P0" ] && [ -d "$P0BASE" ]; then
    BASE="$P0BASE"               # compiled-in present -> it wins
else
    BASE="$PFX/lib/ivl"          # compiled-in absent -> exe-relative to $PFX
fi
UVMSRC="$BASE/uvm/src"
DPIVPI="$BASE/uvm_dpi.vpi"

# Fully detach from the build tree / environment. When the compiled-in root
# was hidden, everything below must be found by exe-relative discovery from
# $PFX; if that failed, even the ivl backend would be unreachable and S1 would
# not compile — so a passing S1 is itself the relocation proof.
export PATH="$PFX/bin:$PATH"
unset IVERILOG_VPI_MODULE_PATH IVERILOG_UVM_HOME 2>/dev/null || true

# The effective runtime tree must also carry the UVM resources; missing DPI
# here is a hard failure (real DPI is required, not a silent fallback).
[ -f "$UVMSRC/uvm_pkg.sv" ] && pass "UVM sources resolvable at $BASE" \
    || fail "UVM sources missing at $UVMSRC"
[ -f "$DPIVPI" ] && pass "UVM DPI runtime resolvable ($DPIVPI)" \
    || fail "UVM DPI runtime missing at $DPIVPI"

# A representative real UVM test copied OUTSIDE the source/build tree.
cp "$SRCROOT/tests/reg_basic_test.sv" "$WORK/tb.sv"
cd "$WORK"

# --------------------------------------------------------------------------
say "S1: basic automatic UVM from an arbitrary directory (no manual paths)"
if "$IVERILOG" -g2012 -uvm -o sim.vvp tb.sv >s1.log 2>&1 ; then
    if grep -q 'error:' s1.log ; then
        fail "compile emitted error: lines"; grep 'error:' s1.log | head -3
    else
        pass "compiled with only '-uvm' (no -I, no uvm_pkg.sv, no -M/-m/-d)"
    fi
    out="$($TO "$VVP" sim.vvp 2>&1)"
    if echo "$out" | grep -q 'UVM_ERROR :    0' && echo "$out" | grep -q 'PASS'; then
        pass "vvp sim.vvp ran clean (UVM_ERROR : 0), no runtime flags"
    else
        fail "vvp run did not pass cleanly"; echo "$out" | tail -6 | sed 's/^/    | /'
    fi
else
    fail "compile failed"; tail -5 s1.log | sed 's/^/    | /'
fi

# --------------------------------------------------------------------------
say "S2: real UVM DPI genuinely loaded (not a UVM_NO_DPI accident)"
# The -uvm program must run with zero 'DPI error' lines...
dpi_with="$($TO "$VVP" sim.vvp 2>&1 | grep -c 'DPI error')"
# ...while the SAME source compiled in real-DPI mode WITHOUT a provider must
# report the missing native symbols, proving the program truly needs them.
"$IVERILOG" -g2012 -I "$UVMSRC" -o nomod.vvp "$UVMSRC/uvm_pkg.sv" tb.sv >s2.log 2>&1
dpi_without="$($TO "$VVP" nomod.vvp 2>&1 | grep -c 'DPI error')"
# And confirm the module is actually baked into the program.
baked="$(grep -c ':vpi_module "[^"]*uvm_dpi' sim.vvp 2>/dev/null || echo 0)"
if [ "$dpi_with" -eq 0 ] && [ "$dpi_without" -gt 0 ] && [ "$baked" -ge 1 ]; then
    pass "native DPI resolved via auto-loaded module ($dpi_without symbols needed, 0 unresolved)"
else
    fail "DPI necessity check (with=$dpi_with expected 0, without=$dpi_without expected >0, baked=$baked expected >=1)"
fi

# --------------------------------------------------------------------------
say "S3: manual low-level override still works (backward compatibility)"
"$IVERILOG" -g2012 -I "$UVMSRC" -o man.vvp "$UVMSRC/uvm_pkg.sv" tb.sv >s3.log 2>&1
out="$($TO "$VVP" -M"$PFX/lib/ivl" -m uvm_dpi man.vvp 2>&1)"
if echo "$out" | grep -q 'UVM_ERROR :    0' && echo "$out" | grep -q 'PASS'; then
    pass "raw -I/uvm_pkg.sv + vvp -M/-m flow unchanged"
else
    fail "manual override flow broke"; echo "$out" | tail -5 | sed 's/^/    | /'
fi

# --------------------------------------------------------------------------
say "S4: --uvm-no-dpi compiles the pure-SystemVerilog fallbacks"
if "$IVERILOG" -g2012 --uvm-no-dpi -o nodpi.vvp tb.sv >s4.log 2>&1 ; then
    if grep -q ':vpi_module "[^"]*uvm_dpi' nodpi.vvp ; then
        fail "--uvm-no-dpi should not bake the UVM DPI module"
    else
        out="$($TO "$VVP" nodpi.vvp 2>&1)"
        echo "$out" | grep -q 'PASS' && pass "--uvm-no-dpi ran without the DPI module" \
            || fail "--uvm-no-dpi run did not pass"
    fi
else
    fail "--uvm-no-dpi compile failed"; tail -5 s4.log | sed 's/^/    | /'
fi

# --------------------------------------------------------------------------
say "S5: --uvm-home override selects an explicit UVM library"
if "$IVERILOG" -g2012 --uvm-home="$UVMSRC" -o home.vvp tb.sv >s5.log 2>&1 \
       && ! grep -q 'error:' s5.log ; then
    out="$($TO "$VVP" home.vvp 2>&1)"
    echo "$out" | grep -q 'UVM_ERROR :    0' && pass "--uvm-home compiled and ran" \
        || fail "--uvm-home run did not pass"
else
    fail "--uvm-home compile failed"; tail -5 s5.log | sed 's/^/    | /'
fi

# --------------------------------------------------------------------------
say "S6: controlled diagnostic when the UVM DPI runtime is missing"
if mv "$DPIVPI" "$DPIVPI.hidden" 2>/dev/null ; then
    diag="$("$IVERILOG" -g2012 -uvm -o miss.vvp tb.sv 2>&1)"
    mv "$DPIVPI.hidden" "$DPIVPI"
    if echo "$diag" | grep -qi 'UVM DPI runtime' && echo "$diag" | grep -qi 'UVM_NO_DPI'; then
        pass "missing DPI runtime produced a clear high-level diagnostic"
    else
        fail "missing DPI runtime did not diagnose clearly"; echo "$diag" | grep -i 'uvm' | head -4 | sed 's/^/    | /'
    fi
else
    echo "  SKIP: runtime tree $BASE not writable (system install); cannot hide the module"
fi

# --------------------------------------------------------------------------
say "S7: controlled diagnostic when the UVM package is missing"
"$IVERILOG" -g2012 --uvm-home=/nonexistent/uvm -o never.vvp tb.sv >s7.log 2>&1
rc=$?
if [ $rc -ne 0 ] && grep -qi 'uvm_pkg.sv' s7.log ; then
    pass "missing UVM package failed with a clear message (exit $rc)"
else
    fail "missing UVM package not handled (exit $rc)"; head -3 s7.log | sed 's/^/    | /'
fi

# --------------------------------------------------------------------------
say "S8: --uvm-version reports the bundled version"
ver="$("$IVERILOG" --uvm-version 2>&1)"
if [ -n "$ver" ] && echo "$ver" | grep -qi 'uvm'; then
    pass "--uvm-version -> $ver"
else
    fail "--uvm-version produced nothing useful: '$ver'"
fi

# --------------------------------------------------------------------------
echo ""
if [ $FAIL -eq 0 ]; then
    echo "UVM front-end regression: ALL SCENARIOS PASSED"
else
    echo "UVM front-end regression: FAILURES ABOVE"
fi
exit $FAIL
