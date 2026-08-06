#!/bin/bash
# fusesoc-wrap.sh — Convenience wrapper for FuseSoC + iverilog-uvm backend
#
# Usage:
#   source scripts/fusesoc-wrap.sh [--ot-root /path/to/opentitan]
#
#   # Then use:
#   fusesoc-uvm core list
#   fusesoc-uvm-compile lint lowrisc:prim:lfsr
#   fusesoc-uvm-otbn    # Build OTBN (the milestone test)
#
# The iverilog_uvm edalize backend is auto-detected from the
# IVERILOG_UVM_ROOT environment variable or by walking up the
# directory tree.

# Determine the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IVERILOG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# OpenTitan root: either from --ot-root or default sibling directory
OT_ROOT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ot-root) OT_ROOT="$2"; shift 2 ;;
        *) shift ;;
    esac done

if [ -z "$OT_ROOT" ]; then
    # Try common locations
    for candidate in \
        "$IVERILOG_ROOT/../opentitan-upstream" \
        "$IVERILOG_ROOT/../opentitan" \
        "$HOME/opentitan"; do
        if [ -d "$candidate" ] && [ -f "$candidate/hw/ip/otbn/otbn.core" ]; then
            OT_ROOT="$candidate"
            break
        fi
    done
fi

export IVERILOG_UVM_ROOT="$IVERILOG_ROOT"

# Find fusesoc binary
FUSESOC=""
for candidate in \
    "$(python3 -c "import sys; print(sys.prefix)")/bin/fusesoc" \
    "$HOME/Library/Python/3.9/bin/fusesoc" \
    "$HOME/Library/Python/3.11/bin/fusesoc" \
    "$HOME/Library/Python/3.12/bin/fusesoc" \
    "$HOME/Library/Python/3.13/bin/fusesoc" \
    "$HOME/.local/bin/fusesoc"; do
    if [ -x "$candidate" ]; then
        FUSESOC="$candidate"
        break
    fi
done

if [ -z "$FUSESOC" ]; then
    echo "ERROR: fusesoc not found. Install: pip3 install 'fusesoc==2.4.5'" >&2
    return 1 2>/dev/null || exit 1
fi

# Verify FuseSoC version (fusesoc.__version__ doesn't exist; use pip)
FUSESOC_VER=$(python3 -c "import pkg_resources; print(pkg_resources.get_distribution('fusesoc').version)" 2>/dev/null || echo "unknown")
if [[ "$FUSESOC_VER" != "2.4.5" ]]; then
    echo "WARNING: fusesoc version is $FUSESOC_VER (expected 2.4.5)" >&2
    echo "  Install correct version: pip3 install 'fusesoc==2.4.5'" >&2
fi

# --- Commands ---

# fusesoc-uvm: run fusesoc with cores-root set and mapping
fusesoc-uvm() {
    local cmd="$1"; shift
    if [ -n "$OT_ROOT" ]; then
        "$FUSESOC" --cores-root="$OT_ROOT" "$cmd" "$@"
    else
        echo "ERROR: No OpenTitan root found. Set OT_ROOT or pass --ot-root." >&2
        echo "  source $0 --ot-root /path/to/opentitan-upstream" >&2
        return 1
    fi
}

# fusesoc-uvm-compile: compile a core (compile-only, no simulation)
fusesoc-uvm-compile() {
    local target="${1:-default}"; shift
    local core="$1"; shift
    if [ -z "$OT_ROOT" ]; then
        echo "ERROR: No OpenTitan root found." >&2; return 1
    fi
    "$FUSESOC" --cores-root="$OT_ROOT" run \
        --target="$target" \
        --tool=iverilog_uvm \
        --mapping lowrisc:prim:generic_mapping:0 \
        "$core" "$@"
}

# fusesoc-uvm-run: run a core (with simulation, if testbench exists)
fusesoc-uvm-run() {
    local target="${1:-default}"; shift
    local core="$1"; shift
    if [ -z "$OT_ROOT" ]; then
        echo "ERROR: No OpenTitan root found." >&2; return 1
    fi
    "$FUSESOC" --cores-root="$OT_ROOT" run \
        --target="$target" \
        --tool=iverilog_uvm \
        --mapping lowrisc:prim:generic_mapping:0 \
        --run \
        "$core" "$@"
}

# fusesoc-uvm-otbn: build OTBN (the milestone test)
fusesoc-uvm-otbn() {
    if [ -z "$OT_ROOT" ]; then
        echo "ERROR: No OpenTitan root found." >&2; return 1
    fi
    echo "Building OTBN..."
    "$FUSESOC" --cores-root="$OT_ROOT" run \
        --target=syn-iverilog \
        --tool=iverilog_uvm \
        --mapping lowrisc:prim:generic_mapping:0 \
        lowrisc:ip:otbn
}

echo "╔══════════════════════════════════════════════╗"
echo "║  fusesoc-uvm wrapper loaded                  ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  IVERILOG_UVM_ROOT = $IVERILOG_ROOT"
if [ -n "$OT_ROOT" ]; then
    echo "║  OT cores root     = $OT_ROOT"
else
    echo "║  OT cores root     = (not found — set with --ot-root)"
fi
echo "║  FuseSoC           = $FUSESOC_VER at $FUSESOC"
echo "╠══════════════════════════════════════════════╣"
echo "║  Commands:                                   ║"
echo "║    fusesoc-uvm core list                     ║"
echo "║    fusesoc-uvm-compile lint <core>           ║"
echo "║    fusesoc-uvm-run lint <core>               ║"
echo "║    fusesoc-uvm-otbn                          ║"
echo "╚══════════════════════════════════════════════╝"
