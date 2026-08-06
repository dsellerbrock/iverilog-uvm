# FuseSoC + iverilog-uvm Setup Guide

This guide explains how to use the **iverilog-uvm fork** with
[FuseSoC](https://github.com/olofk/fusesoc) to build and synthesize
OpenTitan and Caliptra hardware designs.

**Target audience:** humans and AI agents who need a reproducible,
step-by-step recipe from zero to a successful OTBN build.

## Overview

The integration has four components:

| Component | Purpose |
|---|---|
| **iverilog-uvm-opentitan-upstream** | Icarus Verilog fork with SystemVerilog synthesis, SVA, and UVM support |
| **edalize backend** (`iverilog_uvm.py`) | Plugin that teaches FuseSoC how to invoke our iverilog compiler |
| **prim_generic_mapping.core** | Pins virtual prim cores to behavioral (`prim_generic`) implementations |
| **FuseSoC wrapper scripts** | Convenience commands for building IP cores |

## Exact version requirements

| Package | Required version | Why |
|---|---|---|
| `fusesoc` | **==2.4.5** | OpenTitan pins this exact version; 2.4.6+ may work but is untested |
| `edalize` | **>=0.6.8** | Required by FuseSoC; our backend file must be copied into its directory |
| Python | **>=3.9** | Required by FuseSoC |

**Do not** install a different FuseSoC version without testing. The OpenTitan
`.core` files use CAPI=2 format, which FuseSoC 1.x does not understand.

## Prerequisites

- macOS or Linux (tested on macOS 14+)
- Python 3.9+ with pip
- Git
- GNU Bison (for building iverilog)
- GCC or Clang (for building iverilog)

## Step-by-step Installation

### Step 1: Clone and build the iverilog-uvm fork

```bash
git clone https://github.com/dsellerbrock/iverilog-uvm.git
cd iverilog-uvm/iverilog-uvm-opentitan-upstream

# Configure and build
./autoconf.sh
./configure --prefix=$(pwd)/local-install
make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu)
make install

# Verify the build
./driver/iverilog -V
# Expected: "Icarus Verilog version ..."
```

Set the environment variable for later steps:

```bash
export IVERILOG_UVM_ROOT=$(pwd)
```

### Step 2: Install Python dependencies (pin exact versions!)

```bash
pip3 install "fusesoc==2.4.5" "edalize>=0.6.8"
```

Verify:

```bash
fusesoc --version   # Must print "2.4.5"
python3 -c "import edalize; print('OK')"  # Must print "OK"
```

### Step 3: Install the iverilog_uvm edalize backend

The backend lives at `scripts/edalize/iverilog_uvm.py`. Copy it into
edalize's package directory:

```bash
cd /path/to/iverilog-uvm-opentitan-upstream

# Find edalize's directory and install
EDALIZE_DIR=$(python3 -c "
import importlib.util
s = importlib.util.find_spec('edalize')
print(s.submodule_search_locations[0])
")
cp scripts/edalize/iverilog_uvm.py "$EDALIZE_DIR/"

# Verify discovery
python3 -c "
from edalize.edatool import get_edatool
get_edatool('iverilog_uvm')
print('iverilog_uvm backend registered successfully')
"
```

The backend auto-detects the iverilog install path from the
`$IVERILOG_UVM_ROOT` environment variable. Always set it before running
FuseSoC.

### Step 4: Clone OpenTitan and apply compatibility patches

```bash
# Clone OpenTitan (use same parent directory as iverilog-uvm)
cd /path/to/iverilog-uvm
git clone https://github.com/lowRISC/opentitan.git opentitan-upstream
cd opentitan-upstream

# Pin a known-good revision
git checkout 7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19
```

**Required patches to OpenTitan `.core` files:**

Two `.core` files have empty `files: []` in their verilator waiver filesets,
which FuseSoC 2.x rejects as invalid. Apply these fixes:

```bash
# Fix jtag_dtm.core — replace empty files:[] with a placeholder
python3 << 'EOF'
with open('hw/ip/tlul/jtag_dtm.core', 'r') as f:
    content = f.read()
content = content.replace(
    'files: []\n      # - lint/tlul_jtag_dtm.vlt',
    'files:\n      - _placeholder.vlt'
)
with open('hw/ip/tlul/jtag_dtm.core', 'w') as f:
    f.write(content)
EOF

# Fix adapter_dmi.core
python3 << 'EOF'
with open('hw/ip/tlul/adapter_dmi.core', 'r') as f:
    content = f.read()
content = content.replace(
    'files: []\n      # - lint/tlul_adapter_dmi.vlt',
    'files:\n      - _placeholder.vlt'
)
with open('hw/ip/tlul/adapter_dmi.core', 'w') as f:
    f.write(content)
EOF

# Create placeholder files
touch hw/ip/tlul/lint/tlul_jtag_dtm_placeholder.vlt
touch hw/ip/tlul/lint/_placeholder.vlt
```

### Step 5: Install the prim_generic_mapping.core

OpenTitan uses "virtual cores" to swap between ASIC (ASAP7), FPGA (Xilinx),
and behavioral (generic) primitive implementations. FuseSoC chooses
non-deterministically. Our mapping core forces `prim_generic` for synthesis:

```bash
# The mapping core is already generated at:
#   /path/to/iverilog-uvm-opentitan-upstream/hw/ip/prim/prim_generic_mapping.core
#
# But it needs to be in the OpenTitan tree for FuseSoC to find it.
# Link or copy it:

IVERILOG_ROOT=/path/to/iverilog-uvm-opentitan-upstream
cp "$IVERILOG_ROOT/hw/ip/prim/prim_generic_mapping.core" \
   hw/ip/prim/prim_generic_mapping.core
```

> **Note:** The mapping core is also stored in the iverilog-uvm repo at
> `scripts/edalize/../otbn_stubs/../hw/ip/prim/prim_generic_mapping.core`
> for distribution. If it's not there, regenerate it with the command in
> the Troubleshooting section.

### Step 6: Verify the setup

```bash
cd /path/to/opentitan-upstream
export IVERILOG_UVM_ROOT=/path/to/iverilog-uvm-opentitan-upstream

# List available cores (should show ~800+ cores)
fusesoc --cores-root . core list 2>&1 | grep -c "lowrisc:"
# Expected: >700

# Check the mapping core is available
fusesoc --cores-root . core show lowrisc:prim:generic_mapping 2>&1 | head -5
# Expected: "Name: lowrisc:prim:generic_mapping:0"

# Check OTBN resolves
fusesoc --cores-root . core show lowrisc:ip:otbn 2>&1 | head -5
# Expected: "Name: lowrisc:ip:otbn:0.1"
```

### Step 7: Build OTBN (the milestone test)

```bash
cd /path/to/opentitan-upstream
export IVERILOG_UVM_ROOT=/path/to/iverilog-uvm-opentitan-upstream

fusesoc --cores-root . run \
  --target=syn-iverilog \
  --mapping lowrisc:prim:generic_mapping:0 \
  lowrisc:ip:otbn
```

Expected result:
- **Compilation succeeds** — zero errors, zero "sorry" diagnostics
- A ~23 MB binary is produced at `build/lowrisc_ip_otbn_0.1/syn-iverilog-iverilog_uvm/lowrisc_ip_otbn_0.1`
- Only 2 non-fatal "sorry" messages about `otbn_predecode.sv` struct member indexing

## Quick reference: the one-liner

After one-time setup, use this to build any OpenTitan core:

```bash
cd /path/to/opentitan-upstream
export IVERILOG_UVM_ROOT=/path/to/iverilog-uvm-opentitan-upstream

fusesoc --cores-root . run \
  --target=<target> \
  --tool=iverilog_uvm \
  --mapping lowrisc:prim:generic_mapping:0 \
  <core_name>
```

## Convenience scripts

The `scripts/` directory in the iverilog-uvm repo contains helpers:

| Script | Purpose |
|---|---|
| `setup_fusesoc.sh` | One-command setup (runs steps 3, 5, and 6 automatically) |
| `fusesoc-wrap.sh` | Source this to get `fusesoc-uvm` and `fusesoc-uvm-compile` aliases |

```bash
# After building iverilog-uvm:
./scripts/setup_fusesoc.sh --opentitan-path ../opentitan-upstream

# Use the wrapper:
source scripts/fusesoc-wrap.sh
fusesoc-uvm core list
fusesoc-uvm-compile lint lowrisc:prim:lfsr
```

## Architecture

```
┌─────────────────────────────────────────────┐
│ FuseSoC 2.4.5 (build orchestration)          │
│  ├─ Resolves dependency tree (80+ cores)      │
│  ├─ Discovers .core files (CAPI=2)            │
│  ├─ Applies --mapping for virtual core pinning│
│  └─ Invokes edalize backends                  │
├─────────────────────────────────────────────┤
│ edalize 0.6.8 (tool abstraction)              │
│  ├─ icarus.py       (stock Icarus Verilog)    │
│  └─ iverilog_uvm.py (OUR CUSTOM BACKEND)      │
│       ├─ Always passes -g2012                  │
│       ├─ Auto-detects $IVERILOG_UVM_ROOT       │
│       ├─ Points -B at local-install/lib/ivl/  │
│       └─ Supports compile_only mode for synth  │
├─────────────────────────────────────────────┤
│ iverilog-uvm-opentitan-upstream               │
│  ├─ driver/iverilog   (compiler frontend)      │
│  ├─ ivl               (compiler engine)        │
│  ├─ vvp/vvp           (simulation runtime)     │
│  └─ local-install/    (VPI modules, config)    │
└─────────────────────────────────────────────┘
```

## OTBN dependency tree (what `--mapping` resolves)

```
lowrisc:ip:otbn:0.1
├── lowrisc:ip:otbn_pkg     (register package types)
├── lowrisc:ip:tlul:0.1     (TileLink transition core)
│   ├── lowrisc:tlul:socket_1n, socket_m1
│   ├── lowrisc:tlul:adapter_sram, adapter_reg, adapter_dmi
│   ├── lowrisc:tlul:jtag_dtm   (needed .core fix)
│   └── lowrisc:tlul:common, headers, trans_intg
├── lowrisc:prim:all:0.1    (all primitives)
│   ├── lowrisc:prim:xor2  ──maps to──▶ lowrisc:prim_generic:xor2
│   ├── lowrisc:prim:flop  ──maps to──▶ lowrisc:prim_generic:flop
│   ├── ... (30 total virtual-to-generic mappings)
│   └── lowrisc:prim:ram_1p ──maps to──▶ lowrisc:prim_generic:ram_1p
├── lowrisc:ip:sha3:0.1     (SHA-3 accelerator)
├── lowrisc:ip:keymgr_pkg   (key manager types)
├── lowrisc:ip:edn_pkg      (entropy distribution)
├── lowrisc:ip:otp_ctrl_pkg (OTP controller types)
├── lowrisc:ip:kmac_pkg     (KMAC types)
├── lowrisc:ip:lc_ctrl_pkg  (lifecycle controller types)
├── lowrisc:ip:csrng_pkg    (cryptographic RNG types)
└── pulp-platform:riscv-dbg (debug module, vendor core)
```

## Troubleshooting

### "fusesoc: command not found"

```bash
# Find it:
python3 -c "import sys; print(sys.prefix + '/bin/fusesoc')"
# Add to PATH or use full path
```

### "Parse error. Ignoring file jtag_dtm.core"

You skipped Step 4. Apply the `.core` file patches described above.

### "Non-deterministic selection of virtual core prim:xor2"

You forgot the `--mapping` flag. Always include:
```
--mapping lowrisc:prim:generic_mapping:0
```

### "back to back" or "/ivlpp is a directory"

The `-B` flag points wrong. Make sure `$IVERILOG_UVM_ROOT` points to the
directory containing `local-install/lib/ivl/`. Verify:
```bash
ls "$IVERILOG_UVM_ROOT/local-install/lib/ivl/ivl"
# Must exist
```

### "Target has no toplevel"

Some OpenTitan cores are package-only (no synthesizable module). Use
`core show` to find targets with toplevels:
```bash
fusesoc --cores-root . core show <core_name>
```

### "Parameter SYNTHESIS not found"

The target doesn't define that parameter. Check available parameters with
`core show`, or omit the parameter.

### Wrong FuseSoC version

```bash
# Check installed version
fusesoc --version

# If not 2.4.5, reinstall:
pip3 install --force-reinstall "fusesoc==2.4.5"
```

### Regenerating prim_generic_mapping.core

If the mapping core is missing or out of date:

```bash
cd /path/to/opentitan-upstream
python3 << 'PYEOF'
import yaml, glob

virtual_providers = {}
for corefile in glob.glob('**/*.core', recursive=True):
    if '/build/' in corefile:
        continue
    try:
        with open(corefile) as f:
            data = list(yaml.safe_load_all(f))[0]
        if isinstance(data, dict) and 'virtual' in data:
            provider = data['name']
            for v in data.get('virtual', []):
                virtual_providers.setdefault(v, []).append(provider)
    except:
        pass

with open('hw/ip/prim/prim_generic_mapping.core', 'w') as f:
    f.write('CAPI=2:\n')
    f.write('name: "lowrisc:prim:generic_mapping:0"\n')
    f.write('description: "Map virtual prim cores to prim_generic implementations"\n')
    f.write('\nmapping:\n')
    for vcore, providers in sorted(virtual_providers.items()):
        generic = [p for p in providers if 'generic' in p.lower()]
        if generic:
            f.write(f'  {vcore}: {generic[0]}\n')
print("Mapping core regenerated")
PYEOF
```

### For AI agents: key invariants

When debugging build failures, remember:

1. **IVERILOG_UVM_ROOT** must be set before any FuseSoC command
2. **--mapping lowrisc:prim:generic_mapping:0** must be passed for any core
   that depends on primitives (virtually all of them)
3. **FuseSoC 2.4.5 only** — later versions may work but are untested
4. **The .core file patches** (jtag_dtm, adapter_dmi) are required — they
   fix parse errors in the upstream OpenTitan repository
5. **The `syn-iverilog` target** (not `syn`) uses compile_only mode to skip
   vvp simulation for cores without testbenches
