#!/bin/bash
# setup_fusesoc.sh — Automated FuseSoC + iverilog-uvm setup
#
# Usage:
#   cd iverilog-uvm-opentitan-upstream
#   ./scripts/setup_fusesoc.sh [--opentitan-path /path/to/opentitan]
#
# This script:
#   1. Locates the edalize package directory
#   2. Installs the iverilog_uvm.py backend
#   3. Verifies the installation
#   4. (Optional) Links stub packages into an OpenTitan source tree

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IVERILOG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

OPENTITAN_PATH=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --opentitan-path)
            OPENTITAN_PATH="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--opentitan-path /path/to/opentitan]"
            echo ""
            echo "Installs the iverilog_uvm edalize backend and optionally links"
            echo "stub packages into an OpenTitan source tree."
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

echo "========================================"
echo " FuseSoC + iverilog-uvm Setup"
echo "========================================"
echo ""

# --- Step 1: Verify iverilog-uvm build ---
info "Checking iverilog-uvm installation..."
if [ ! -f "$IVERILOG_ROOT/driver/iverilog" ]; then
    error "driver/iverilog not found. Build with: ./autoconf.sh && ./configure && make"
fi
if [ ! -f "$IVERILOG_ROOT/local-install/lib/ivl/ivl" ]; then
    error "local-install/lib/ivl/ivl not found. Run: make install"
fi
IVERILOG_VER=$("$IVERILOG_ROOT/driver/iverilog" -V 2>&1 | head -1) || true
info "Found: $IVERILOG_VER"

# --- Step 2: Verify Python dependencies ---
info "Checking Python dependencies..."
python3 -c "import edalize" 2>/dev/null || error "edalize not installed. Run: pip3 install edalize"
python3 -c "import fusesoc" 2>/dev/null || error "fusesoc not installed. Run: pip3 install fusesoc"
info "Python dependencies OK"

# --- Step 3: Install edalize backend ---
# edalize is a namespace package; locate via site-packages
EDALIZE_DIR=$(python3 -c "
import importlib.util, os
spec = importlib.util.find_spec('edalize')
if spec and spec.submodule_search_locations:
    print(spec.submodule_search_locations[0])
else:
    # Fallback: search site-packages
    import site
    for d in site.getsitepackages():
        p = os.path.join(d, 'edalize')
        if os.path.isdir(p):
            print(p)
            break
")
BACKEND_SRC="$SCRIPT_DIR/edalize/iverilog_uvm.py"
BACKEND_DST="$EDALIZE_DIR/iverilog_uvm.py"

info "Installing edalize backend..."
info "  Source: $BACKEND_SRC"
info "  Dest:   $BACKEND_DST"

if [ ! -f "$BACKEND_SRC" ]; then
    error "Backend source not found at $BACKEND_SRC"
fi

cp "$BACKEND_SRC" "$BACKEND_DST"
info "Backend installed."

# --- Step 4: Verify backend discovery ---
info "Verifying backend discovery..."
if python3 -c "from edalize.edatool import get_edatool; get_edatool('iverilog_uvm'); print('OK')" 2>&1 | grep -q "OK"; then
    info "Backend discovered by edalize ✓"
else
    error "Backend not discovered. Check edalize installation."
fi

# --- Step 5: Generate patch file ---
PATCH_FILE="$IVERILOG_ROOT/iverilog_uvm_backend.patch"
info "Generating distribution patch: $PATCH_FILE"
cd "$EDALIZE_DIR"
diff -u /dev/null iverilog_uvm.py > "$PATCH_FILE" 2>/dev/null || true
info "Patch written to $PATCH_FILE"

# --- Step 6: Link stub packages (optional) ---
if [ -n "$OPENTITAN_PATH" ]; then
    if [ -d "$OPENTITAN_PATH" ]; then
        info "Linking stub packages into OpenTitan tree at $OPENTITAN_PATH"
        STUBS_DIR="$SCRIPT_DIR/otbn_stubs"
        for stub in "$STUBS_DIR"/*.sv; do
            pkg_name=$(basename "$stub" | sed 's/_pkg.*//' | sed 's/_stub//')
            # Try to find the right target directory
            for candidate in \
                "$OPENTITAN_PATH/hw/ip/$pkg_name/rtl/" \
                "$OPENTITAN_PATH/hw/ip/prim/rtl/"; do
                if [ -d "$candidate" ]; then
                    cp "$stub" "$candidate/"
                    info "  Linked: $(basename $stub) → $candidate"
                    break
                fi
            done
        done
    else
        warn "OpenTitan path does not exist: $OPENTITAN_PATH"
        warn "Skipping stub package installation."
        warn ""
        warn "To install stubs later, copy files from scripts/otbn_stubs/"
        warn "into the appropriate OpenTitan IP directories."
    fi
fi

# --- Step 7: Print summary ---
echo ""
echo "========================================"
echo " Setup Complete"
echo "========================================"
echo ""
echo "To use FuseSoC with iverilog-uvm:"
echo ""
echo "  source $SCRIPT_DIR/fusesoc-wrap.sh"
echo "  fusesoc-uvm core list"
echo "  fusesoc-uvm-compile lint lowrisc:prim:lfsr"
echo ""
echo "Environment variable:"
echo "  export IVERILOG_UVM_ROOT=$IVERILOG_ROOT"
echo ""
echo "Distribution patch:"
echo "  $PATCH_FILE"
echo ""
echo "To apply on another machine after building iverilog-uvm:"
echo "  1. Copy iverilog_uvm_backend.patch to the target machine"
echo "  2. cd \$(python3 -c 'import importlib.util; s=importlib.util.find_spec(\"edalize\"); print(s.submodule_search_locations[0])')"
echo "  3. patch -p0 < /path/to/iverilog_uvm_backend.patch"
