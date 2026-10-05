# OTBN smoke pre-run recovery — 2026-10-05

The census17 `lowrisc:dv:otbn_sim:0.1` row completed FuseSoC setup and Icarus
compile with zero hard errors, then reported `PRE_RUN_FAIL` before simulation.
Its fallback toolchain script requires Git metadata and Bash associative arrays;
the copied OpenTitan source has no `.git`, and macOS `/bin/bash` is 3.2.

The matrix runner already accepts `RV32_TOOL_AS` and `RV32_TOOL_LD`. With those
set to the installed xPack tools and the OpenTitan Python environment on
`PATH`, the smoke binary generator succeeds on the exact census17 source
snapshot. The `PATH` entry is needed because `otbn_as.py` uses `python3` through
`/usr/bin/env` and imports PyYAML.

```sh
OT_ROOT=/private/tmp/ot-corpus-current-spid-passthrough-20261003/source
OT_ENV=/Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313
RV32_BIN=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/evidence/caliptra-verilator-l0-enable-20260923/toolchain/xpack-riscv-none-elf-gcc-12.2.0-3/riscv-none-elf/bin
OUT=/private/tmp/pi/otbn-census17-xpack-pre-run-path-20261005/binaries
mkdir -p "$OUT"
PATH="$OT_ENV/bin:$PATH" RV32_TOOL_AS="$RV32_BIN/as" RV32_TOOL_LD="$RV32_BIN/ld" \
  "$OT_ENV/bin/python" "$OT_ROOT/hw/ip/otbn/dv/uvm/gen-binaries.py" \
  --src-dir "$OT_ROOT/hw/ip/otbn/dv/smoke" "$OUT"
```

The generated `smoke_test.elf` is a statically linked 32-bit RISC-V ELF with
SHA-256 `c4c9eac89b7880fc39c5524f20d70be1bf6c1e8fe4053ddae592c663ee490777`.
This verifies only the pre-run recovery. A full runtime invocation with the
xPack environment is still required to count OTBN toward a coherent 49/49
result.
