# OpenTitan 49-target runtime matrix

The 2026-10-04 census passed all 49 selected Earlgrey runtime targets. It used
OpenTitan revision `a78922f14a8cc20c7ee569f322a04626f2ac6127`, UVM 1.2,
`-gcommercial-unsafe`, two parallel jobs, and the three source overlays below.
This qualifies the matrix's selected runtime lane, not every OpenTitan DV test.
See the [census results and provenance](../../evidence/opentitan-census-20261002/census13-full-corpus-20261004/README.md),
[hot-path analysis](../../evidence/opentitan-census-20261002/census12-full-corpus-20261003/HOTPATHS.md),
and the general [matrix runner reference](opentitan_matrix.md).

## Apply the published overlays

The patch files are in this repository and should be applied only to a
disposable OpenTitan checkout. From the compiler fork root, run:

- [OTP covergroup purity](../../evidence/opentitan-census-20261002/census12-full-corpus-20261003/compat-patches/otp-get-offset-covergroup-purity.patch)
- [Flash element-wise solve ordering](../../evidence/opentitan-census-20261002/census12-full-corpus-20261003/compat-patches/flash-elementwise-solve-before.patch)
- [SPI TPM SRAM/reset wiring](../../evidence/opentitan-census-20261002/census12-full-corpus-20261003/compat-patches/spi-tpm-sram-csb-reset.patch)

```bash
OT_ROOT=/tmp/opentitan-census13
git clone https://github.com/lowRISC/opentitan.git "$OT_ROOT"
git -C "$OT_ROOT" checkout a78922f14a8cc20c7ee569f322a04626f2ac6127
PATCH_DIR="$PWD/evidence/opentitan-census-20261002/census12-full-corpus-20261003/compat-patches"

for name in \
  otp-get-offset-covergroup-purity.patch \
  flash-elementwise-solve-before.patch \
  spi-tpm-sram-csb-reset.patch; do
  patch --dry-run -p1 -d "$OT_ROOT" < "$PATCH_DIR/$name"
done
for name in \
  otp-get-offset-covergroup-purity.patch \
  flash-elementwise-solve-before.patch \
  spi-tpm-sram-csb-reset.patch; do
  patch -p1 -d "$OT_ROOT" < "$PATCH_DIR/$name"
done
```

## Run the matrix concurrently

Build and install this fork first. Provide the pinned UVM 1.2 sources, a
FuseSoC environment with OpenTitan dependencies, native OpenSSL/libelf
development packages, and the xPack RISC-V assembler/linker used by OTBN.
`--jobs` runs independent cores concurrently. The recorded pass used two jobs;
raise `JOBS` to 4 on a machine with enough CPU and memory to reduce overall
wall time. Runtime memory limits apply per process on macOS, so include the
number of concurrent jobs in the memory estimate.

```bash
# Export JOBS=4 before this block to run four cores concurrently.
OT_ROOT="${OT_ROOT:-/tmp/opentitan-census13}"
JOBS="${JOBS:-2}"
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
