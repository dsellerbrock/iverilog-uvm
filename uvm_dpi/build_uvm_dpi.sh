#!/bin/sh
#
# Build the standard UVM DPI umbrella (uvm_dpi.vpi) with iverilog-vpi.
#
# The umbrella (uvm_dpi_iverilog.cc) combines the vendored, tool-independent
# Accellera UVM DPI sources (regex, command-line, common reporting bridge)
# with an Icarus HDL-backdoor backend built on standard IEEE 1800 VPI. It is
# a loadable VPI module: `iverilog -uvm' bakes a `:vpi_module "uvm_dpi";'
# request into the compiled program and vvp loads it automatically, so the
# user never names a shared library.
#
# This script exists so the compile/link quirks that differ across platforms
# live in exactly one place, shared by the toolchain install (Makefile) and
# the CI regression harness (.github/uvm_test.sh):
#
#   * Linux  : iverilog-vpi's @shared@ (`-shared') links; the undefined sv*/
#              vpi_* imports bind lazily against vvp at load time.
#   * macOS  : same, but <malloc.h> (pulled in by the vendored uvm_dpi.h) does
#              not exist as a top-level header — shim it to <stdlib.h>.
#   * Windows: a DLL must resolve every import at link time. The sv* DPI-
#              context API is exported by vvp.exe (vvp/vvp.def) but ships in
#              no archive, and POSIX regex must be linked explicitly, so build
#              a dedicated sv* import library and add it plus -lregex.
#
# Usage:
#   IVPI=<iverilog-vpi> [VVP_DEF=<path/to/vvp.def>] \
#       build_uvm_dpi.sh --name=<out-without-.vpi> <iverilog-vpi args...>
#
# All arguments are passed through to iverilog-vpi unchanged; this wrapper
# only appends the platform-specific include/library options. IVPI defaults
# to `iverilog-vpi' found on PATH. Returns iverilog-vpi's exit status.

set -e

IVPI=${IVPI:-iverilog-vpi}

EXTRA_INC=""
EXTRA_LIB=""

case "$(uname -s)" in
    Darwin)
        # No top-level <malloc.h> on macOS; forward it to <stdlib.h>, which
        # declares malloc/free/realloc.
        shim="${TMPDIR:-/tmp}/uvm_dpi_compat"
        mkdir -p "$shim"
        printf '#include <stdlib.h>\n' > "$shim/malloc.h"
        EXTRA_INC="-I$shim"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        # NOTE: on Windows the standalone global umbrella this helper builds is
        # NOT the supported real-DPI path — the UVM regression suite
        # (.github/uvm_test.sh) instead merges the umbrella with each design's
        # generated DPI-export stub per test, because the per-design dispatcher
        # m__uvm_report_dpi cannot bind across separately loaded PE modules, and
        # because the umbrella's imports must be published with
        # -Wl,--export-all-symbols (which iverilog-vpi cannot pass). So this
        # build is expected to fall back; installuvm then installs the UVM
        # sources only and `iverilog -uvm` uses UVM_NO_DPI with a clear
        # diagnostic. The flags below still mirror the proven ones so the
        # attempt is correct as far as it goes:
        #   * import the WHOLE vvp.def (vpi_* AND sv* AND __ivl_dpi_export_call_*)
        #     from vvp.exe, not just sv* — libvpi.a's vpi_* shims assert for a
        #     -d library, and the umbrella needs vvp's real routines;
        #   * link regex via libsystre/tre, not a bare -lregex, whose <regex.h>
        #     often disagrees with the linked regex_t layout and corrupts every
        #     UVM config_db wildcard match.
        if command -v dlltool >/dev/null 2>&1 && [ -n "$VVP_DEF" ] && [ -f "$VVP_DEF" ] ; then
            implib="${TMPDIR:-/tmp}/libvvpimp.a"
            if dlltool -d "$VVP_DEF" -D vvp.exe -l "$implib" 2>/dev/null ; then
                EXTRA_LIB="-L${TMPDIR:-/tmp} -lvvpimp"
            fi
        fi
        EXTRA_LIB="$EXTRA_LIB -lsystre -ltre"
        ;;
esac

exec "$IVPI" "$@" $EXTRA_INC $EXTRA_LIB
