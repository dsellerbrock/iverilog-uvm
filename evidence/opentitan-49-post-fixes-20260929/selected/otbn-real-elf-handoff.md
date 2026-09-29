# OTBN selected smoke triage — 2026-09-29

The full-corpus OTBN row compiles with zero hard errors but fails at time 0 because the matrix runner records `en_run_modes` and `+otbn_elf_dir=...` as unresolved; it does not run OpenTitan's `build_otbn_smoke_binary_mode` or pass the resolved plusarg. The previous baseline had the same missing-plusarg failure and missing DPI symbols. The current full row has all native DPI sources built.

## Real smoke ELF

OpenTitan's `otbn_sim_cfg.hjson` names `build_otbn_smoke_binary_mode`; that mode invokes `gen-binaries.py --src-dir hw/ip/otbn/dv/smoke` and produces `smoke_test.elf`, the exact filename required by `otbn_smoke_vseq.sv`.

Command used (output only in `/private/tmp`):

```sh
mkdir -p /private/tmp/otbn-smoke-selected-20260929/binaries
PATH=/Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313/bin:$PATH RV32_TOOL_AS=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/evidence/caliptra-verilator-l0-enable-20260923/toolchain/xpack-riscv-none-elf-gcc-12.2.0-3/riscv-none-elf/bin/as RV32_TOOL_LD=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/evidence/caliptra-verilator-l0-enable-20260923/toolchain/xpack-riscv-none-elf-gcc-12.2.0-3/riscv-none-elf/bin/ld /Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313/bin/python /private/tmp/ot-corpus-after-fixes-20260929/source/hw/ip/otbn/dv/uvm/gen-binaries.py --src-dir /private/tmp/ot-corpus-after-fixes-20260929/source/hw/ip/otbn/dv/smoke /private/tmp/otbn-smoke-selected-20260929/binaries
```

SHA-256:

- Generated ELF: `e47c6d70669a8b2837e8476b6e3ca1eeaadb98b62bab87321a0ce698348cb827`
- Smoke assembly: `f7b726056628b8932d5fa0326610e9ecbeebb1314a41c631dedb62bf24616089`
- `gen-binaries.py`: `6499042274402b3d8a7983526e73472b654339042b2446101d017ee9bd62e71b`
- xPack assembler: `cd43ba4f68f0b54926ecd421ff687de5ff92192480fe9948f62044d0abf26c97`
- xPack linker: `8ecbe023d553605ae98416d55b95f698c3181cd29c54c51c8ab7742de4e84d06`

## Bounded selected replay

Used the full-row `runtime_command` from `/private/tmp/ot-corpus-after-fixes-20260929/result-final.json`, appended `+otbn_elf_dir=/private/tmp/otbn-smoke-selected-20260929/binaries`, and set `REPO_TOP=/private/tmp/ot-corpus-after-fixes-20260929/source` (as OpenTitan's DV config exports). Set `IVL_SVA_NFA=1` and prepended the pinned Python venv to `PATH`, as the corpus runner does. Invoked the existing `opentitan_matrix.command_result` memory monitor with a 4 GiB physical-footprint limit and 180-second timeout. The exact VVP argument vector and result are in `selected-result-repotop.json`.

The test loaded `smoke_test.elf` at 1,107,307 ps and polled for OTBN completion at 1,336,480 and 4,055,317 ps. First UVM error: `UVM_ERROR @ 25733094 ps: (tlul_assert.sv:301) [ASSERT FAILED] noOutstandingReqsAtEndOfSim_A`. The log then reports `TEST FAILED CHECKS` and `$finish`, but the process remained alive until the 180-second guard stopped it. Return code 124, `timed_out=true`, peak physical footprint 2,716,076,360 bytes, no pass banner. This is **not** an OTBN DV pass. The earlier selected baseline reached a scope lookup error around 4 us; this replay advanced to 25.7 us.

Artifacts: `selected-result-repotop.json`, `selected-runtime-repotop.log`, and `binaries/smoke_test.elf` in this directory. An earlier exploratory run omitted `REPO_TOP`, produced repeated ISS-wrapper errors and SIGSEGV, and is preserved as `selected-result.json` / `selected-runtime.log`; it is superseded by the replay above. No repository or pinned OpenTitan source files were edited.
