#!/bin/bash
# fusesoc-wrap.sh — Convenience wrapper for FuseSoC + iverilog-uvm backend
#
# Usage:
#   source scripts/fusesoc-wrap.sh                    # Set up environment
#   fusesoc-uvm run --target=lint lowrisc:prim:lfsr   # Build a core
#   fusesoc-uvm core show lowrisc:ip:otbn:0.1         # Show core info
#
# The iverilog_uvm edalize backend is auto-detected from the
# IVERILOG_UVM_ROOT environment variable or by walking up the
# directory tree.

# Determine the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IVERILOG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OT_ROOT="$(cd "$IVERILOG_ROOT/../opentitan-upstream" && pwd)"

export IVERILOG_UVM_ROOT="$IVERILOG_ROOT"

# Find fusesoc
FUSESOC="$(python3 -c "import sys; print(sys.prefix)")/bin/fusesoc"
if [ ! -x "$FUSESOC" ]; then
    FUSESOC="$HOME/Library/Python/3.9/bin/fusesoc"
fi

if [ ! -x "$FUSESOC" ]; then
    echo "ERROR: fusesoc not found at $FUSESOC" >&2
    echo "Install with: pip3 install fusesoc" >&2
    return 1
fi

# Function: fusesoc-uvm — run fusesoc with our backend
fusesoc-uvm() {
    "$FUSESOC" --cores-root="$OT_ROOT" "$@"
}

# Function: fusesoc-uvm-compile — run fusesoc with iverilog_uvm backend
fusesoc-uvm-compile() {
    local target="${1:-default}"
    local core="$2"
    shift 2 2>/dev/null || true
    "$FUSESOC" --cores-root="$OT_ROOT" run --setup --build --no-export \
        --target="$target" --tool=iverilog_uvm "$core" "$@"
}

echo "fusesoc-uvm ready. FUSESOC=$FUSESOC"
echo "IVERILOG_UVM_ROOT=$IVERILOG_UVM_ROOT"
echo "OT cores root: $OT_ROOT"
echo ""
echo "Commands:"
echo "  fusesoc-uvm core list                         # List all cores"
echo "  fusesoc-uvm core show lowrisc:ip:otbn:0.1     # Show core info"
echo "  fusesoc-uvm-compile lint lowrisc:prim:lfsr    # Compile a core"
