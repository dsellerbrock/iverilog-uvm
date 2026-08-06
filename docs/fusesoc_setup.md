# FuseSoC + iverilog-uvm Setup Guide

This guide explains how to use the [Icarus Verilog UVM fork](https://github.com/dsellerbrock/iverilog-uvm)
with [FuseSoC](https://github.com/olofk/fusesoc) to build and simulate
OpenTitan and Caliptra hardware designs.

## Overview

The integration has three components:

1. **iverilog-uvm-opentitan-upstream** — the Icarus Verilog fork with
   SystemVerilog synthesis, SVA, and UVM support for OpenTitan/Caliptra.
2. **edalize backend** (`iverilog_uvm.py`) — a FuseSoC/edalize plugin that
   teaches FuseSoC how to invoke the iverilog-uvm compiler.
3. **FuseSoC wrapper scripts** — convenience commands for building IP cores.

## Prerequisites

- macOS or Linux (tested on macOS 14+)
- Python 3.9+ with pip
- Git
- GNU Bison (for building iverilog)
- GCC or Clang (for building iverilog)

## Step-by-step Installation

### 1. Clone and build the iverilog-uvm fork

```bash
git clone https://github.com/dsellerbrock/iverilog-uvm.git
cd iverilog-uvm

# The fork lives in the iverilog-uvm-opentitan-upstream subdirectory
cd iverilog-uvm-opentitan-upstream

# Configure and build
./autoconf.sh
./configure --prefix=$(pwd)/local-install
make -j$(nproc)
make install

# Verify
./driver/iverilog -V
# Should print: Icarus Verilog version ...
```

### 2. Install FuseSoC and Python dependencies

```bash
pip3 install fusesoc edalize
```

### 3. Install the iverilog_uvm edalize backend

The backend file is at `scripts/edalize/iverilog_uvm.py`. Copy it into
edalize's package directory so FuseSoC can discover it:

```bash
# Find edalize's package directory
EDALIZE_DIR=$(python3 -c "import edalize, os; print(os.path.dirname(os.path.abspath(edalize.__file__)))")

# Install the backend
cp scripts/edalize/iverilog_uvm.py "$EDALIZE_DIR/"

# Verify discovery
python3 -c "from edalize.edatool import get_edatool; get_edatool('iverilog_uvm'); print('OK')"
```

If the above command prints `OK`, the backend is installed successfully.

### 4. Set up the OpenTitan core library

```bash
# Clone OpenTitan (if not already present)
git clone https://github.com/lowRISC/opentitan.git
cd opentitan

# Check out a known-good revision
git checkout 7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19
```

### 5. (Optional) Generate register packages

Some OpenTitan IPs (like OTBN) depend on generated register packages
(`*_reg_pkg.sv`, `*_dpe_pkg.sv`). These are produced by OpenTitan's Bazel
build system. For quick testing, you can use the stub packages in
`scripts/otbn_stubs/`:

```bash
# Link stub packages into the OpenTitan source tree
for f in scripts/otbn_stubs/*.sv; do
    # Adjust paths as needed — these are for OTBN's dependencies
    cp "$f" ../opentitan/hw/ip/$(basename "$f" | sed 's/_pkg.*//')/rtl/
done
```

For production use, generate the real packages:

```bash
cd ../opentitan
./bazelisk.sh build //hw/ip/otbn:otbn_reg_pkg
# ... repeat for other IPs
```

### 6. Quick test

```bash
# Source the convenience wrapper
source scripts/fusesoc-wrap.sh

# Verify FuseSoC can discover our backend
fusesoc-uvm core list 2>/dev/null | grep "iverilog_uvm"

# Build a simple core
fusesoc-uvm-compile lint lowrisc:prim:lfsr
```

## Usage

### One-line setup (after install)

```bash
cd iverilog-uvm-opentitan-upstream
export IVERILOG_UVM_ROOT=$(pwd)
source scripts/fusesoc-wrap.sh
```

### Building an IP core

```bash
# Build and simulate
fusesoc-uvm run --target=lint --tool=iverilog_uvm lowrisc:prim:edge_detector

# Build only (no simulation)
fusesoc-uvm-compile lint lowrisc:prim:lfsr

# Show core information
fusesoc-uvm core show lowrisc:ip:otbn:0.1
```

### Building OTBN (requires generated register packages)

```bash
fusesoc-uvm run --target=lint-core --tool=iverilog_uvm lowrisc:ip:otbn:0.1
```

## Troubleshooting

### "Backend iverilog_uvm not found"

The edalize backend wasn't installed correctly. Re-run step 3.

### "/ivlpp is a directory" or "system.vpi not found"

The `-B` flag is pointing to the wrong directory. Set
`IVERILOG_UVM_ROOT` to the `iverilog-uvm-opentitan-upstream` directory
that contains the `local-install` subdirectory.

### "Target has no toplevel"

Some OpenTitan cores are package-only and don't have a top-level module.
Use `fusesoc-uvm core show <core>` to find targets that have a toplevel.

### "Parameter SYNTHESIS not found"

Some targets require parameters. Pass them via `--flag`:
```bash
fusesoc-uvm run --target=lint --flag=SYNTHESIS --tool=iverilog_uvm <core>
```

## Architecture

```
┌─────────────────────────────────────────────┐
│ FuseSoC (build orchestration)                │
│  ├─ Resolves dependency tree                 │
│  ├─ Discovers .core files                    │
│  └─ Invokes edalize backends                 │
├─────────────────────────────────────────────┤
│ edalize (tool abstraction)                   │
│  ├─ icarus.py      (stock Icarus Verilog)    │
│  └─ iverilog_uvm.py (OUR CUSTOM BACKEND)     │
├─────────────────────────────────────────────┤
│ iverilog-uvm-opentitan-upstream              │
│  ├─ driver/iverilog  (compiler frontend)     │
│  ├─ ivl              (compiler engine)       │
│  ├─ vvp/vvp          (simulation runtime)    │
│  └─ local-install/   (VPI modules, config)   │
└─────────────────────────────────────────────┘
```

## Distributing the backend

The edalize backend is a single self-contained Python file. To distribute it:

```bash
# Generate a patch for the edalize installation
cd /path/to/edalize/site-packages
diff -u /dev/null edalize/iverilog_uvm.py > iverilog_uvm_backend.patch

# Or just copy the file
cp iverilog-uvm-opentitan-upstream/scripts/edalize/iverilog_uvm.py \
   $(python3 -c "import edalize; import os; print(os.path.dirname(edalize.__file__))")/
```

The backend has no dependencies beyond edalize itself and works with any
FuseSoC 2.x installation.
