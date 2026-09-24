# Pinned Caliptra L0 replay and full-DV gap

## Result

The complete selected Caliptra v2.1.2 L0 replay produced **51/52 passes, one failed case, and zero timeouts**. Firmware builds completed for all 52 cases using the documented, focused compatibility overlays. `smoke_test_doe_scan` is the sole failure: both commands returned 0 and the log includes a pass banner, but it also includes one SVA error (`DOE STATUS valid bit not set after clear obf secrets cmd`). Per policy, an SVA error is a failed case. No assertion was disabled or rewritten. See [`full_l0_summary.json`](full_l0_summary.json) for each case's command/result/log/ELF hashes, [`full_l0.run.log`](full_l0.run.log) for the runner output, and [`runs_batch.tar.gz`](runs_batch.tar.gz) for all case-specific raw logs and command/result records.

The replay used pinned Caliptra v2.1.2 `49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e` and Adams Bridge v2.0.3 `b77e3d899e828d626cfc2a0d26a6b5704cc121e0`, in a disposable source copy. It used Verilator 5.050 as a read-only differential simulator and xPack RISC-V GCC 15.2.0-1 (`rv32imc/ilp32`). Approved overlays and resulting source hashes are recorded in the JSON summary. The pinned original checkouts remain unmodified. This is an L0 Verilator replay, **not full UVM DV qualification**.

The selected firmware overlays were independently replayed first: `smoke_test_hw_config` passed in 102.44 s and `smoke_test_hmac_errortrigger` passed in 192.99 s. Each had one pass banner, no fail banner, and no SVA errors. Their individual result and raw make logs are retained beside this README.

## Official full-DV scope and local gaps

The pinned inventory counts 293 YAML test definitions (Caliptra 241; Adams Bridge 52), 33 regression group lists, and 44 unit RTL `.vf` entrypoints. These include integration firmware-driven tests, directed/random block tests, and UVMF top/block environments. The separate 44-entry Icarus unit census is compile-only (20 compile/elaboration images, 6 compiler failures, 17 missing-input/setup cases, 1 unsupported VVP target); it is not a runtime regression. Existing bounded Icarus runtime evidence covers 2,048 `power2round_tb` vectors and a known-failing pristine 100-vector `rej_bounded_tb` probe.

VCS is absent, so the release's official VCS integration, unit, and UVMF regressions cannot run here. The proprietary UVMF 2022.3, QVIP 2021.2.1, Avery AXI VIP 2025.1, licensed ARM Axi4PC, and JTAG DPI inputs required by applicable targets are also absent. Local tools include Icarus 13.0, VVP, Verilator 5.050, the xPack RISC-V GCC toolchain above, Python, and the workspace's pinned FuseSoC Python environment. GCC and Verilator were verified for the selected L0 replay; FuseSoC is not required by that direct Makefile runner. The inventory's stale availability prose says GCC/FuseSoC are unavailable; use the direct checks and hashes here for the selected replay's tool status. No full suite is claimed.

## First reproducible Icarus source blocker

The first included-source compiler diagnostic in the pinned CSRNG unit filelist is its package order: `csrng_tb.vf` lists `caliptra_prim_generic_ram_1p.sv` at line 28, before `caliptra_prim_ram_1p_pkg.sv` at line 44, while the module imports that package at line 9. IEEE 1800-2017 and 1800-2023 §26.3 say: “The compilation of a package shall precede the compilation of scopes in which the package is imported.” See [`csrng_package_order.md`](csrng_package_order.md) for local standard PDF hashes and the bounded paired-order probe. This is a filelist ordering issue under the standard's ordered compilation rule, not evidence that Icarus should scan forward for packages.

A disposable filelist overlay moves only the package entry before the importing module; its SHA-256 is `9d98286d50cd2e345914d27ac8ee4a9ea55acf530c8e8517e0bcbdd0e073a8bb`. The narrowed full `csrng_tb` Icarus compile then proceeds beyond the unknown-package error but stops at a different missing input: `aes_clp_wrapper.sv:26: Include file caliptra_reg_field_defines.svh not found`. The exact compile log, overlay diff, and paired-order logs are under [`csrng_order_probe/`](csrng_order_probe/). Slang results are differential evidence only, not proof of VCS behavior.

## Reproduction

From this evidence directory, the recorded selected L0 invocation was:

```sh
python3 run_all.py --timeout 900 > full_l0.run.log 2>&1
```

The runner SHA-256, case-specific command JSON, per-case result JSON, per-case make logs, and simulator logs are retained. Extract `runs_batch.tar.gz` from this directory to inspect the `runs_batch/` paths named in the summary. The archive SHA-256 is in `full_l0_summary.json`. Reproduction requires the pinned source revisions, the three documented approved overlays, the verified tool aliases, and an isolated output tree. Keep `smoke_test_doe_scan` failed until a corrected simulator passes the unchanged assertion with zero SVA errors; the [causal reset trace](../caliptra-doe-root-cause-20260923/assessment.md) identifies the current Verilator defect.
