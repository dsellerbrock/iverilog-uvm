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
        # Build an import library exposing ONLY vvp's sv* exports (kept
        # separate so it does not collide with libvpi's vpi_* definitions),
        # then link it plus the regex provider.
        if command -v dlltool >/dev/null 2>&1 && [ -n "$VVP_DEF" ] && [ -f "$VVP_DEF" ] ; then
            tmpdef="${TMPDIR:-/tmp}/uvm_sv.def"
            implib="${TMPDIR:-/tmp}/libuvmsv.a"
            { printf 'EXPORTS\n'; grep -E '^sv[A-Za-z]' "$VVP_DEF"; } > "$tmpdef"
            if dlltool -d "$tmpdef" -D vvp.exe -l "$implib" 2>/dev/null ; then
                EXTRA_LIB="-L${TMPDIR:-/tmp} -luvmsv"
            fi
        fi
        EXTRA_LIB="$EXTRA_LIB -lregex"
        ;;
esac

exec "$IVPI" "$@" $EXTRA_INC $EXTRA_LIB
