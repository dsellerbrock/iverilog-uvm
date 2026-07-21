#!/usr/bin/env bash
# Windows DPI / POSIX-regex diagnostic probe.
#
# Real UVM DPI on Windows fails in two clusters: (1) UVM config_db regex
# matching (UVM/DPI/REGEX), (2) DPI import/export returning 0. This probe
# isolates the root cause quickly (seconds, no UVM dependency) so we stop
# guessing:
#   A) native regcomp() on a UVM-style pattern, linked several ways, prints
#      sizeof(regex_t) + the regcomp/regexec return codes. A header/lib
#      regex_t mismatch shows up as regcomp != 0 (or a size that differs
#      between providers).
#   B) a minimal DPI call: SV passes a string to C and gets back its length
#      (int return). If PROBE_LEN is wrong, DPI string-arg / int-return
#      marshaling is broken on Windows — which would explain BOTH clusters
#      and means the regex provider is a red herring.
# Purely diagnostic: never fails the job.
set +e
echo "==================== WIN DPI/REGEX PROBE ===================="
echo "--- uname / toolchain ---"
uname -a
gcc --version | head -1
echo "MSYSTEM=$MSYSTEM  MINGW_PREFIX=$MINGW_PREFIX"

echo "--- which top-level <regex.h> resolves, and its provider ---"
printf '#include <regex.h>\n' > /tmp/rxwhich.c
gcc -E /tmp/rxwhich.c 2>/dev/null | grep -m1 -iE 'regex\.h' | sed 's/^/  /'
ls -l "$MINGW_PREFIX/include/regex.h" 2>/dev/null | sed 's/^/  /'
# who owns it?
if command -v pacman >/dev/null 2>&1 ; then
    pacman -Qo "$MINGW_PREFIX/include/regex.h" 2>/dev/null | sed 's/^/  owner: /'
fi

echo "--- native regcomp() probe, linked several ways ---"
cat > /tmp/rxsz.c <<'PROBEEOF'
#include <stdio.h>
#include <regex.h>
int main(void) {
    printf("  sizeof(regex_t)=%zu\n", sizeof(regex_t));
    regex_t re;
    int e = regcomp(&re, "uvm_test_top.*", REG_EXTENDED);
    printf("  regcomp(\"uvm_test_top.*\", REG_EXTENDED)=%d\n", e);
    if (e == 0) {
        int m = regexec(&re, "uvm_test_top.foo", 0, 0, 0);
        printf("  regexec(\"uvm_test_top.foo\")=%d (0=match)\n", m);
        regfree(&re);
    } else {
        char buf[256];
        regerror(e, &re, buf, sizeof buf);
        printf("  regerror: %s\n", buf);
    }
    return 0;
}
PROBEEOF
for lib in "" "-lsystre -ltre" "-lregex" "-lgnurx" "-ltre"; do
    if gcc /tmp/rxsz.c -o /tmp/rxsz $lib 2>/tmp/rxsz.err ; then
        echo "  [link: '${lib:-<none>}'] ->"
        /tmp/rxsz
    else
        echo "  [link: '${lib:-<none>}'] link failed: $(head -1 /tmp/rxsz.err)"
    fi
done

echo "--- DPI marshaling-shape probe (which DPI shapes work in a loaded module?) ---"
# uvm_re_compexecfree returns a BIT and has an OUTPUT int arg, and calls regcomp
# INSIDE the loaded module. The cluster-2 failures (divmod outputs, sum_int open
# arrays) are also non-scalar shapes. Test each shape so we know exactly which
# marshaling path is broken on Windows (int-return already known good = 16).
cat > /tmp/dpi_probe.sv <<'PROBEEOF'
module top;
  import "DPI-C" function int     p_int(input string s);
  import "DPI-C" function bit     p_bit(input int x);
  import "DPI-C" function byte    p_byte(input int x);
  import "DPI-C" function void    p_out(input int x, output int y);
  import "DPI-C" function int     p_regcomp(input string re);
  initial begin
    int y;
    $display("p_int=%0d   (exp 16)", p_int("uvm_test_top.abc"));
    $display("p_bit=%0d    (exp 1)", p_bit(5));
    $display("p_byte=%0d  (exp 42)", p_byte(0));
    y = 0; p_out(7, y); $display("p_out.y=%0d (exp 8)", y);
    $display("p_regcomp=%0d (exp 0 = regcomp ok inside loaded module)", p_regcomp("uvm_test_top.*"));
    $finish;
  end
endmodule
PROBEEOF
cat > /tmp/dpi_probe.c <<'PROBEEOF'
#include <string.h>
#include <regex.h>
int  p_int(const char* s)      { return s ? (int)strlen(s) : -1; }
unsigned char p_bit(int x)     { return x ? 1 : 0; }
char p_byte(int x)             { (void)x; return (char)42; }
void p_out(int x, int* y)      { *y = x + 1; }
int  p_regcomp(const char* re) {
    regex_t r; int e = regcomp(&r, re, REG_EXTENDED);
    if (!e) regfree(&r);
    return e;
}
PROBEEOF
IVPI="$(dirname "$(command -v iverilog)")/iverilog-vpi"
iverilog -g2012 -o /tmp/dpi_probe.vvp /tmp/dpi_probe.sv 2>&1 | sed 's/^/  ivl: /'
# Build the probe module the SAME way the umbrella is built on Windows:
# link the regex provider so regcomp resolves inside the loaded module.
( cd /tmp && "$IVPI" --name=/tmp/dpi_probe_lib /tmp/dpi_probe.c -lsystre -ltre ) 2>&1 | sed 's/^/  vpi: /'
vvp -d /tmp/dpi_probe_lib.vpi /tmp/dpi_probe.vvp 2>&1 | sed 's/^/  run: /'

echo "--- ACTUAL UVM uvm_regex.cc (extern \"C\"-wrapped, as the umbrella builds it) ---"
# All primitives above work in isolation, so build the real uvm_regex.cc the way
# the umbrella does (wrapped in extern "C") and call uvm_re_compexecfree directly.
# On Linux this returns ok=1; if Windows returns ok=0, this reproduces the UVM
# regex failure minimally (no full umbrella / stub / -luvmsv), isolating whether
# it is the regex provider or the uvm_regex.cc code path itself.
REPO_DIR="$(pwd)"
printf 'extern "C" {\n#include <stdlib.h>\n#include "uvm_regex.cc"\n}\n' > /tmp/re_umbrella.cc
cat > /tmp/re_probe.sv <<'PROBEEOF'
module retop;
  import "DPI-C" function bit uvm_re_compexecfree(string re, string str, bit deglob, output int exec_ret);
  initial begin
    int r; bit ok;
    ok = uvm_re_compexecfree("uvm_test_top.*", "uvm_test_top.foo", 1'b0, r);
    $display("RE_COMPEXECFREE ok=%0d exec_ret=%0d (exp ok=1 exec_ret=0)", ok, r);
    $finish;
  end
endmodule
PROBEEOF
iverilog -g2012 -o /tmp/re_probe.vvp /tmp/re_probe.sv 2>&1 | sed 's/^/  ivl: /'
for lib in "-lsystre -ltre" "-lregex" "-lgnurx"; do
    echo "  [regex lib: $lib]"
    if ( cd /tmp && "$IVPI" --name=/tmp/re_probe_lib -I"$REPO_DIR/uvm-core/src/dpi" \
              /tmp/re_umbrella.cc $lib ) >/tmp/re_vpi.log 2>&1 ; then
        vvp -d /tmp/re_probe_lib.vpi /tmp/re_probe.vvp 2>&1 \
            | grep -aE "RE_COMPEXECFREE|error|not found" | sed 's/^/    run: /'
    else
        echo "    build failed:"; tail -3 /tmp/re_vpi.log | sed 's/^/    /'
    fi
done

echo "--- FULL umbrella: dummy externals (A) vs real -luvmsv import lib (B) ---"
# The isolated uvm_regex.cc works; the full umbrella content works too (Linux).
# So bisect the suite build: does the -luvmsv dlltool import library (the most
# novel part of the Windows umbrella link) break the regex that otherwise works?
cat > /tmp/dummies_all.c <<'PROBEEOF'
void* svGetScope(void){return 0;} void* svSetScope(void*s){return s;}
void* svGetScopeFromName(const char*n){(void)n;return 0;}
const char* svGetNameFromScope(void*s){(void)s;return "";}
const char* svGetFullNameFromScope(void*s){(void)s;return "";}
void m__uvm_report_dpi(int a,const char*b,const char*c,int d,const char*e,int f){(void)a;(void)b;(void)c;(void)d;(void)e;(void)f;}
long long __ivl_dpi_export_call_i(const char*n,int a,void*p){(void)n;(void)a;(void)p;return 0;}
double __ivl_dpi_export_call_r(const char*n,int a,void*p){(void)n;(void)a;(void)p;return 0;}
const char* __ivl_dpi_export_call_s(const char*n,int a,void*p){(void)n;(void)a;(void)p;return "";}
void __ivl_dpi_export_call_v(const char*n,int a,void*p){(void)n;(void)a;(void)p;}
PROBEEOF
cat > /tmp/dummies_report.c <<'PROBEEOF'
void m__uvm_report_dpi(int a,const char*b,const char*c,int d,const char*e,int f){(void)a;(void)b;(void)c;(void)d;(void)e;(void)f;}
PROBEEOF
echo "  [A: full umbrella + all dummies + -lsystre -ltre]"
if ( cd /tmp && "$IVPI" --name=/tmp/fa_lib -I"$REPO_DIR/uvm-core/src/dpi" \
          "$REPO_DIR/uvm_dpi/uvm_dpi_iverilog.cc" /tmp/dummies_all.c -lsystre -ltre ) >/tmp/fa.log 2>&1 ; then
    vvp -d /tmp/fa_lib.vpi /tmp/re_probe.vvp 2>&1 | grep -aE "RE_COMPEXECFREE|error|not found" | sed 's/^/    run: /'
else
    echo "    build failed:"; tail -3 /tmp/fa.log | sed 's/^/    /'
fi
echo "  [B: full umbrella + report dummy + dlltool -luvmsv + -lsystre -ltre]"
if command -v dlltool >/dev/null 2>&1 && [ -f "$REPO_DIR/vvp/vvp.def" ] ; then
    { printf 'EXPORTS\n'; grep -E '^(sv[A-Za-z]|__ivl_dpi_export_call_)' "$REPO_DIR/vvp/vvp.def"; } > /tmp/uvm_sv.def
    dlltool -d /tmp/uvm_sv.def -D vvp.exe -l /tmp/libuvmsv.a 2>/tmp/dll.log && echo "    (import lib built)" || { echo "    dlltool failed:"; cat /tmp/dll.log | sed 's/^/    /'; }
    if ( cd /tmp && "$IVPI" --name=/tmp/fb_lib -I"$REPO_DIR/uvm-core/src/dpi" \
              "$REPO_DIR/uvm_dpi/uvm_dpi_iverilog.cc" /tmp/dummies_report.c -L/tmp -luvmsv -lsystre -ltre ) >/tmp/fb.log 2>&1 ; then
        vvp -d /tmp/fb_lib.vpi /tmp/re_probe.vvp 2>&1 | grep -aE "RE_COMPEXECFREE|error|not found" | sed 's/^/    run: /'
    else
        echo "    build failed:"; tail -3 /tmp/fb.log | sed 's/^/    /'
    fi
else
    echo "    (dlltool or vvp.def unavailable — skipping B)"
fi
echo "  [C: full umbrella, HAND-ROLLED link with -Wl,--export-all-symbols (the fix)]"
IVL_INC_P="$(dirname "$(dirname "$(command -v iverilog)")")/include/iverilog"
CC_F="$("$IVPI" --cflags 2>/dev/null) -I$IVL_INC_P"; CXX_F="$("$IVPI" --ccflags 2>/dev/null) -I$IVL_INC_P"
LD_F="$("$IVPI" --ldflags 2>/dev/null)"; LD_L="$("$IVPI" --ldlibs 2>/dev/null)"
if g++ -c $CXX_F -I"$REPO_DIR/uvm-core/src/dpi" "$REPO_DIR/uvm_dpi/uvm_dpi_iverilog.cc" -o /tmp/fc_umb.o 2>/tmp/fc.log \
   && gcc -c $CC_F /tmp/dummies_all.c -o /tmp/fc_dum.o 2>>/tmp/fc.log \
   && g++ $LD_F -Wl,--export-all-symbols -o /tmp/fc_lib.vpi /tmp/fc_umb.o /tmp/fc_dum.o -lsystre -ltre $LD_L 2>>/tmp/fc.log ; then
    vvp -d /tmp/fc_lib.vpi /tmp/re_probe.vvp 2>&1 | grep -aE "RE_COMPEXECFREE|error|not found" | sed 's/^/    run: /'
else
    echo "    build failed:"; tail -4 /tmp/fc.log | sed 's/^/    /'
fi
echo "============================================================"

# --- m3_constraint_dynforeach corner: z3 dynamic-foreach element solve ------
# Windows-only failure: ranged_size (`da[i] == base + i`) writes garbage for
# i>=1 while fixed_size passes and no delem fallback warning fires. Enable the
# vvp solver trace (IVL_Z3_DYNDBG, added to vvp_z3.cc) so the artifact shows the
# expansion count, per-instance folded index, and each solved write-back value.
# Compare against the Linux baseline: ranged_size expands to
#   body=<(eq (delem 0:32 L) (add p:1:8 L))> with count == solved size and
#   write-back bits == base, base+1, base+2, ... (contiguous). A divergence in
#   count or in the write-back bits localizes the Windows corner.
echo "[m3] z3 dynamic-foreach element solve trace (IVL_Z3_DYNDBG)"
M3_SRC="$REPO_DIR/tests/m3_constraint_dynforeach_test.sv"
if [ -f "$M3_SRC" ] && command -v iverilog >/dev/null 2>&1 ; then
    if iverilog -g2012 -o /tmp/m3_probe.vvp "$M3_SRC" >/tmp/m3.log 2>&1 ; then
        echo "  pass/fail line:"
        IVL_Z3_DYNDBG=1 vvp /tmp/m3_probe.vvp 2>/tmp/m3_trace.txt \
            | grep -aE "PASS|FAIL" | sed 's/^/    /'
        echo "  ranged_size (base-coupled) solve(s) — expansion, insts, and the"
        echo "  element write-backs that immediately follow (bits should equal"
        echo "  base, base+1, base+2, base+3 if the solver bound them):"
        # Each ranged_size randomize call prints, contiguously: the 'add p:1:8'
        # expansion, its 4 inst lines, then (after the z3 solve) the 4 elem
        # write-back lines. -A16 captures the whole block; two blocks are plenty.
        grep -aA16 'add p:1:8 L)' /tmp/m3_trace.txt \
            | grep -aE 'add p:1:8 L\)|inst i=|writeback prop=|\] prop ' \
            | head -28 | sed 's/^/    /'
        echo "  FAILED element lines (if any):"
        grep -a "FAILED" /tmp/m3_trace.txt | sed 's/^/    /' | head -8
    else
        echo "  compile failed:"; tail -4 /tmp/m3.log | sed 's/^/    /'
    fi
else
    echo "  (m3 source or iverilog unavailable — skipping)"
fi
echo "============================================================"
exit 0
