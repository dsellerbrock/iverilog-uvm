#!/bin/bash
# setup_fusesoc.sh — Automated FuseSoC + iverilog-uvm setup
#
# Usage:
#   cd iverilog-uvm-opentitan-upstream
#   ./scripts/setup_fusesoc.sh [--opentitan-path /path/to/opentitan]
#
# This script:
#   1. Verifies the iverilog-uvm build
#   2. Installs Python deps (pins fusesoc==2.4.5)
#   3. Installs the iverilog_uvm.py edalize backend
#   4. Patches OpenTitan .core files (jtag_dtm, adapter_dmi)
#   5. Installs prim_generic_mapping.core
#   6. Verifies the full setup end-to-end

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IVERILOG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
step()  { echo -e "\n${CYAN}== Step $1: $2 ==${NC}"; }

OPENTITAN_PATH=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --opentitan-path)
            OPENTITAN_PATH="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: $0 [--opentitan-path /path/to/opentitan]"
            echo "Installs the iverilog_uvm edalize backend, patches OpenTitan,"
            echo "and sets up prim_generic_mapping for virtual core resolution."
            exit 0 ;;
        *) error "Unknown option: $1" ;;
    esac
done

echo "========================================"
echo " FuseSoC + iverilog-uvm Setup"
echo "========================================"

# ── Step 1: Verify iverilog-uvm build ──────────────────────
step 1 "Verifying iverilog-uvm build"
if [ ! -f "$IVERILOG_ROOT/driver/iverilog" ]; then
    error "driver/iverilog not found. Build with: ./autoconf.sh && ./configure && make"
fi
if [ ! -f "$IVERILOG_ROOT/local-install/lib/ivl/ivl" ]; then
    error "local-install/lib/ivl/ivl not found. Run: make install"
fi
IVERILOG_VER=$("$IVERILOG_ROOT/driver/iverilog" -V 2>&1 | head -1) || true
info "Found: $IVERILOG_VER"
export IVERILOG_UVM_ROOT="$IVERILOG_ROOT"

# ── Step 2: Install Python deps with exact versions ────────
step 2 "Installing Python dependencies (fusesoc==2.4.5, edalize>=0.6.8)"
FUSESOC_VERSION=$(python3 -c "import pkg_resources; print(pkg_resources.get_distribution('fusesoc').version)" 2>/dev/null || echo "none")
EDALIZE_VERSION=$(python3 -c "import pkg_resources; print(pkg_resources.get_distribution('edalize').version)" 2>/dev/null || echo "none")
info "Current: fusesoc=$FUSESOC_VERSION, edalize=$EDALIZE_VERSION"

NEED_INSTALL=false
if [ "$FUSESOC_VERSION" != "2.4.5" ]; then
    warn "fusesoc version is $FUSESOC_VERSION, need 2.4.5"
    NEED_INSTALL=true
fi
if ! python3 -c "import edalize" 2>/dev/null; then
    warn "edalize not installed"
    NEED_INSTALL=true
fi

if [ "$NEED_INSTALL" = true ]; then
    info "Installing fusesoc==2.4.5 and edalize>=0.6.8..."
    pip3 install "fusesoc==2.4.5" "edalize>=0.6.8" 2>&1 | tail -3
    FUSESOC_VERSION=$(python3 -c "import pkg_resources; print(pkg_resources.get_distribution('fusesoc').version)" 2>/dev/null || echo "FAILED")
    if [ "$FUSESOC_VERSION" != "2.4.5" ]; then
        error "Failed to install fusesoc==2.4.5. Got: $FUSESOC_VERSION"
    fi
    info "Installed: fusesoc=$FUSESOC_VERSION"
else
    info "Python dependencies OK (fusesoc==2.4.5, edalize installed)"
fi

# ── Step 3: Install edalize backend ────────────────────────
step 3 "Installing iverilog_uvm edalize backend"
EDALIZE_DIR=$(python3 -c "
import importlib.util, os
spec = importlib.util.find_spec('edalize')
if spec and spec.submodule_search_locations:
    print(spec.submodule_search_locations[0])
else:
    import site
    for d in site.getsitepackages():
        p = os.path.join(d, 'edalize')
        if os.path.isdir(p):
            print(p)
            break
")
BACKEND_SRC="$SCRIPT_DIR/edalize/iverilog_uvm.py"
BACKEND_DST="$EDALIZE_DIR/iverilog_uvm.py"

info "Source: $BACKEND_SRC"
info "Dest:   $BACKEND_DST"

if [ ! -f "$BACKEND_SRC" ]; then
    error "Backend source not found at $BACKEND_SRC"
fi

cp "$BACKEND_SRC" "$BACKEND_DST"
info "Backend copied."

if python3 -c "from edalize.edatool import get_edatool; get_edatool('iverilog_uvm')" 2>/dev/null; then
    info "Backend discovered by edalize ✓"
else
    error "Backend not discovered. Check edalize installation."
fi

# ── Step 4: Generate patch file ────────────────────────────
step 4 "Generating distribution patch"
PATCH_FILE="$IVERILOG_ROOT/iverilog_uvm_backend.patch"
cd "$EDALIZE_DIR"
diff -u /dev/null iverilog_uvm.py > "$PATCH_FILE" 2>/dev/null || true
info "Patch: $PATCH_FILE ($(wc -l < "$PATCH_FILE") lines)"

# ── Step 5: Patch OpenTitan .core files ────────────────────
if [ -n "$OPENTITAN_PATH" ] && [ -d "$OPENTITAN_PATH" ]; then
    step 5 "Patching OpenTitan .core files"

    # Fix jtag_dtm.core
    JTAG_CORE="$OPENTITAN_PATH/hw/ip/tlul/jtag_dtm.core"
    if [ -f "$JTAG_CORE" ]; then
        if grep -q 'files: \[\]' "$JTAG_CORE" 2>/dev/null; then
            info "Patching jtag_dtm.core (empty files: [])..."
            python3 -c "
with open('$JTAG_CORE', 'r') as f:
    c = f.read()
c = c.replace('files: []\n      # - lint/tlul_jtag_dtm.vlt',
              'files:\n      - _placeholder.vlt')
with open('$JTAG_CORE', 'w') as f:
    f.write(c)
" && info "  ✓ jtag_dtm.core patched"
        else
            info "  jtag_dtm.core already patched or doesn't need it"
        fi
    fi

    # Fix adapter_dmi.core
    ADAPTER_CORE="$OPENTITAN_PATH/hw/ip/tlul/adapter_dmi.core"
    if [ -f "$ADAPTER_CORE" ]; then
        if grep -q 'files: \[\]' "$ADAPTER_CORE" 2>/dev/null; then
            info "Patching adapter_dmi.core (empty files: [])..."
            python3 -c "
with open('$ADAPTER_CORE', 'r') as f:
    c = f.read()
c = c.replace('files: []\n      # - lint/tlul_adapter_dmi.vlt',
              'files:\n      - _placeholder.vlt')
with open('$ADAPTER_CORE', 'w') as f:
    f.write(c)
" && info "  ✓ adapter_dmi.core patched"
        else
            info "  adapter_dmi.core already patched or doesn't need it"
        fi
    fi

    # Create placeholder lint files
    touch "$OPENTITAN_PATH/hw/ip/tlul/lint/tlul_jtag_dtm_placeholder.vlt" 2>/dev/null || true
    touch "$OPENTITAN_PATH/hw/ip/tlul/lint/_placeholder.vlt" 2>/dev/null || true
    info "  ✓ Placeholder lint files created"

    # ── Step 6: Install prim_generic_mapping.core ──────────
    step 6 "Installing prim_generic_mapping.core"
    # The mapping core is in our repo
    MAPPING_SRC="$IVERILOG_ROOT/hw/ip/prim/prim_generic_mapping.core"
    MAPPING_DST="$OPENTITAN_PATH/hw/ip/prim/prim_generic_mapping.core"

    if [ -f "$MAPPING_SRC" ]; then
        cp "$MAPPING_SRC" "$MAPPING_DST"
        info "  ✓ prim_generic_mapping.core installed"
    else
        warn "  Mapping core not found at $MAPPING_SRC"
        warn "  Run 'python3 scripts/generate_mapping_core.py' to create it"
    fi

    # ── Step 7: Add syn-iverilog target to OTBN ────────────
    step 7 "Adding syn-iverilog target to OTBN core"
    OTBN_CORE="$OPENTITAN_PATH/hw/ip/otbn/otbn.core"
    if [ -f "$OTBN_CORE" ]; then
        if ! grep -q 'syn-iverilog:' "$OTBN_CORE" 2>/dev/null; then
            info "Adding compile-only syn-iverilog target..."
            cat >> "$OTBN_CORE" << 'TARGETEOF'

  syn-iverilog:
    <<: *default_target
    default_tool: iverilog_uvm
    parameters:
      - SYNTHESIS=true
    tools:
      iverilog_uvm:
        compile_only: true
TARGETEOF
            info "  ✓ syn-iverilog target added to otbn.core"
        else
            info "  syn-iverilog target already exists"
        fi
    fi
else
    step 5 "Skipping OpenTitan patches (no --opentitan-path)"
    warn "To patch OpenTitan and install mapping core, re-run with:"
    warn "  $0 --opentitan-path /path/to/opentitan-upstream"
fi

# ── Summary ────────────────────────────────────────────────
echo ""
echo "========================================"
echo " Setup Complete"
echo "========================================"
echo ""
echo "Environment:"
echo "  export IVERILOG_UVM_ROOT=$IVERILOG_ROOT"
echo ""
echo "Quick test (after sourcing the wrapper):"
echo "  source $SCRIPT_DIR/fusesoc-wrap.sh"
echo "  fusesoc-uvm core show lowrisc:prim:generic_mapping"
echo ""

if [ -n "$OPENTITAN_PATH" ] && [ -d "$OPENTITAN_PATH" ]; then
    echo "Build OTBN:"
    echo "  cd $OPENTITAN_PATH"
    echo "  export IVERILOG_UVM_ROOT=$IVERILOG_ROOT"
    echo "  fusesoc --cores-root . run --target=syn-iverilog \\"
    echo "    --mapping lowrisc:prim:generic_mapping:0 lowrisc:ip:otbn"
fi

echo ""
echo "Distribution:"
echo "  Backend patch: $PATCH_FILE"
echo "  Docs:          $IVERILOG_ROOT/docs/fusesoc_setup.md"
