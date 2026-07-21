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

echo "--- DPI string-arg + int-return marshaling probe (iverilog) ---"
cat > /tmp/dpi_probe.sv <<'PROBEEOF'
module top;
  import "DPI-C" function int probe_len(input string s);
  initial begin
    int n;
    n = probe_len("uvm_test_top.abc");
    $display("PROBE_LEN=%0d (expect 16)", n);
    $finish;
  end
endmodule
PROBEEOF
cat > /tmp/dpi_probe.c <<'PROBEEOF'
#include <string.h>
int probe_len(const char* s) { return s ? (int)strlen(s) : -1; }
PROBEEOF
IVPI="$(dirname "$(command -v iverilog)")/iverilog-vpi"
iverilog -g2012 -o /tmp/dpi_probe.vvp /tmp/dpi_probe.sv 2>&1 | sed 's/^/  ivl: /'
( cd /tmp && "$IVPI" --name=/tmp/dpi_probe_lib /tmp/dpi_probe.c ) 2>&1 | sed 's/^/  vpi: /'
vvp -d /tmp/dpi_probe_lib.vpi /tmp/dpi_probe.vvp 2>&1 | sed 's/^/  run: /'
echo "============================================================"
exit 0
