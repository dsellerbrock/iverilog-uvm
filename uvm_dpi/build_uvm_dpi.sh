#!/bin/sh
#
# Build the standard UVM DPI umbrella (uvm_dpi.vpi) as a single global,
# loadable VPI module for the `iverilog -uvm' front end (used by `make
# install' -> installuvm). This is distinct from the regression suite's
# per-test *merged* module (.github/uvm_test.sh): here the umbrella stands
# alone, so it is built with -DUVM_DPI_STANDALONE, which supplies a dead-code
# fallback for the per-design m__uvm_report_dpi export (see uvm_dpi_iverilog.cc).
#
# The umbrella combines the vendored, tool-independent Accellera UVM DPI
# sources (regex, command-line, common reporting bridge) with an Icarus
# HDL-backdoor backend on standard IEEE 1800 VPI. `iverilog -uvm' bakes a
# `:vpi_module "uvm_dpi.vpi";' request into the compiled program and vvp loads
# it automatically, so the user never names a shared library.
#
# Platform handling:
#   * Linux/macOS: wrap iverilog-vpi, which supplies the correct @shared@/PIC
#     flags and links -lvpi. The undefined sv*/vpi_* imports bind lazily
#     against vvp at load (macOS needs a <malloc.h> -> <stdlib.h> shim).
#   * Windows/MSYS2: iverilog-vpi cannot pass -Wl,--export-all-symbols, which
#     vvp needs to resolve the umbrella's DPI imports by name (GetProcAddress),
#     so hand-roll the compile/link with the same proven flags the regression
#     suite uses: import the WHOLE vvp.def from vvp.exe (vpi_* AND sv* AND
#     __ivl_dpi_export_call_*), link regex via libsystre/tre (a bare -lregex
#     disagrees on the regex_t layout and corrupts every wildcard match), and
#     force --export-all-symbols. Do NOT link libvpi.a: its vpi_* wrappers
#     dispatch through a callback pointer and would not reach vvp's real
#     routines here.
#
# Usage (arguments mirror iverilog-vpi):
#   IVPI=<iverilog-vpi> [VVP_DEF=<path/to/vvp.def>] \
#       build_uvm_dpi.sh --name=<out-without-.vpi> [-I<dir>...] <src.cc>
#
# Returns non-zero on failure; the caller (installuvm) then falls back to
# installing the UVM sources only.

set -e

IVPI=${IVPI:-iverilog-vpi}
TMP="${TMPDIR:-/tmp}"

# Split the iverilog-vpi-style arguments into the pieces the Windows hand-roll
# needs, while leaving them intact for the Linux/macOS pass-through.
OUT=""
SRCS=""
INCS=""
for a in "$@"; do
    case "$a" in
        --name=*) OUT="${a#--name=}" ;;
        *.c|*.cc|*.cpp) SRCS="$SRCS $a" ;;
        -I*) INCS="$INCS $a" ;;
        *) : ;;   # -L etc.: not needed by the hand-roll
    esac
done

case "$(uname -s)" in
    Darwin)
        # No top-level <malloc.h> on macOS; forward it to <stdlib.h>.
        shim="$TMP/uvm_dpi_compat"
        mkdir -p "$shim"
        printf '#include <stdlib.h>\n' > "$shim/malloc.h"
        exec "$IVPI" "$@" -DUVM_DPI_STANDALONE "-I$shim"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        CXX="$(command -v g++ || command -v clang++ || command -v c++)"
        CCFLAGS="$("$IVPI" --ccflags 2>/dev/null || true)"
        LDFLAGS="$("$IVPI" --ldflags 2>/dev/null || true)"

        EXTRA=""
        if command -v dlltool >/dev/null 2>&1 && [ -n "${VVP_DEF:-}" ] && [ -f "$VVP_DEF" ] ; then
            if dlltool -d "$VVP_DEF" -D vvp.exe -l "$TMP/libvvpimp.a" 2>/dev/null ; then
                EXTRA="-L$TMP -lvvpimp"
            fi
        fi
        EXTRA="$EXTRA -lsystre -ltre"

        obj="$TMP/uvm_dpi_umbrella.o"
        # shellcheck disable=SC2086
        "$CXX" -c $CCFLAGS $INCS -DUVM_DPI_STANDALONE $SRCS -o "$obj"
        # shellcheck disable=SC2086
        "$CXX" $LDFLAGS -Wl,--export-all-symbols -o "$OUT.vpi" "$obj" $EXTRA
        ;;
    *)
        exec "$IVPI" "$@" -DUVM_DPI_STANDALONE
        ;;
esac
