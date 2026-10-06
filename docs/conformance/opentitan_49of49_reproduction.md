# OpenTitan 49-target runtime matrix

The 2026-10-05 census18 passed all 49 selected Earlgrey runtime targets on the
installed pre-candidate compiler. Its historical source copy had no Git
metadata; its exact source content is now reconstructible from the pinned
Earlgrey-PROD-M6 revision. The candidate compiler's matching 49-target runtime
revalidation is a separate run. See the
[historical census results](../../evidence/opentitan-census-20261002/census18-xpack-runtime-20261005/README.md),
[candidate compile and source provenance](../../evidence/opentitan-census-20261002/candidate-census18-pinned-compile-20261005/README.md),
[hot-path analysis](../../evidence/opentitan-census-20261002/census12-full-corpus-20261003/HOTPATHS.md),
and the [matrix runner reference](opentitan_matrix.md).

## Reconstruct the census18 source

Keep the pinned checkout pristine. Create a disposable copy at the pinned
Earlgrey-PROD-M6 commit, apply the consolidated source overlay, then run the
hash-checked Trial1 relocation helper. The bundle captures the materialized
source overlay used by census18; individual per-test patches remain listed in
the [release overlay index](release_overlays/README.md).

From the compiler fork root:

```bash
CHECKOUT=/tmp/opentitan-pinned-checkout
OT_ROOT=/tmp/opentitan-census18
git clone --recursive https://github.com/lowRISC/opentitan.git "$CHECKOUT"
git -C "$CHECKOUT" checkout a78922f14a8cc20c7ee569f322a04626f2ac6127
git -C "$CHECKOUT" submodule update --init --recursive
mkdir -p "$OT_ROOT"
rsync -a --exclude='.git' "$CHECKOUT/" "$OT_ROOT/"

OVERLAY="$PWD/evidence/opentitan-census-20261002/candidate-census18-pinned-compile-20261005/source-overlay.patch"
patch --dry-run -p1 -d "$OT_ROOT" < "$OVERLAY"
patch -p1 -d "$OT_ROOT" < "$OVERLAY"
python3 docs/conformance/release_overlays/opentitan/trial1_core_layout_overlay.py "$OT_ROOT"
```

The overlay SHA-256 and per-file output hashes are in
[`source-provenance.json`](../../evidence/opentitan-census-20261002/candidate-census18-pinned-compile-20261005/source-provenance.json).
It verifies the reconstructed tree against the prior runtime input while
excluding `.git` metadata and Python bytecode caches.

## Run the matrix concurrently

Build and install this fork first. Provide the pinned UVM 1.2 sources, a
FuseSoC environment with OpenTitan dependencies, native OpenSSL/libelf
development packages, and the xPack RISC-V assembler/linker used by OTBN.
Use one job as the safe default. The runtime cap applies per process, so two
jobs can consume twice that amount and four jobs can consume four times as much.
Increase concurrency only after checking the machine's free memory and the
measured peak footprint of a single worker.

```bash
# Set JOBS=2 or 4 only if the machine has enough memory for concurrent caps.
OT_ROOT="${OT_ROOT:-/tmp/opentitan-census18}"
JOBS="${JOBS:-1}"
RUNTIME_MEMORY_MIB="${RUNTIME_MEMORY_MIB:-9536}"
FUSESOC=/path/to/fusesoc-env/bin/fusesoc
FUSESOC_PYTHON=/path/to/fusesoc-env/bin/python
UVM_HOME=/path/to/uvm-1.2/src
RV32_TOOLS=/path/to/xpack-riscv-none-elf/bin
RESULT_DIR=/tmp/opentitan-census
mkdir -p "$RESULT_DIR"
export RV32_TOOL_AS="$RV32_TOOLS/as"
export RV32_TOOL_LD="$RV32_TOOLS/ld"

python3 scripts/opentitan_matrix.py \
  --opentitan-root "$OT_ROOT" \
  --build-root /tmp/iverilog-opentitan-build \
  --iverilog "$PWD/install/bin/iverilog" \
  --uvm-home "$UVM_HOME" \
  --fusesoc "$FUSESOC" \
  --fusesoc-python "$FUSESOC_PYTHON" \
  --lane runtime \
  --jobs "$JOBS" \
  --runtime-memory-mib "$RUNTIME_MEMORY_MIB" \
  --setup-timeout 600 \
  --compile-timeout 600 \
  --runtime-timeout 18000 \
  --commercial-unsafe \
  --native-pkg-config openssl \
  --native-pkg-config libelf \
  --result-json "$RESULT_DIR/result.json" \
  --result-md "$RESULT_DIR/result.md"
```

For the recorded macOS memory guard, append `--runtime-memory-mib 9536` to cap
each VVP process at 9,536 MiB. That option is macOS-only. The exact archived
launcher uses machine-local paths; the command above is the portable template.
`-gcommercial-unsafe` enables nonstandard compatibility behavior and is not an
IEEE conformance mode.
