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
echo "============================================================"
exit 0
