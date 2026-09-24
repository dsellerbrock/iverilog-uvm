# Fresh Caliptra / Adams Bridge Icarus baseline (2026-09-23)

## Provenance

- Caliptra v2.1.2: `49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e`, clean checkout.
- Adams Bridge v2.0.3: `b77e3d899e828d626cfc2a0d26a6b5704cc121e0`, clean submodule checkout.
- Icarus: `local-install/bin/iverilog`, 13.0 (devel), SHA-256 `1590b064aee694d390f8e18b1ca3469a5a47405397db9b8e385b6c5b41f1a5a2`.
- VVP: `local-install/bin/vvp`, 13.0 (devel), SHA-256 `5d4d0ca6bbaa695927572bdbba03915a07e20005403a5fe0d7e25e7e659c16ed`.
- Frozen inventory: `evidence/caliptra-full-dv-inventory-20260923/inventory.json`, SHA-256 `413bb36923db2b50103a24b40ed65bb2a00277d996b0119b3315cf273f02ba21`.

## Results

The exact strict full-top profile was freshly compiled with `-g2017 -gassertions -tnull -s caliptra_top_tb`, released defines, and the established filelist-only removal of the unused proprietary Axi4PC sentinel plus `+timescale+1ns/1ps`. It stopped in 9.058 seconds with 46 interface variable-driver errors. The selected L0 denominator is 52; runtime attempted is **0/52** and runtime outcome is **UNRUN**. The top is compile-blocked, so this is not 52 runtime failures and no L0 pass rate is measured. Full command and logs: `top_command.json`, `top_result.json`, `top.stdout.log`, and `top.stderr.log`.

Fresh compile/elaboration of all 44 frozen unit RTL filelists used the documented census profile `-g2012 -gassertions -s <top> -f <pinned filelist>` where a runnable command existed, with separate output and a 60-second limit. Results: **20 compile PASS, 6 compile FAIL, 17 SETUP, 1 UNSUPPORTED / 44**. These are compile classifications, not DV passes. Setup denotes known missing release inputs/include roots or absent runnable command in the frozen inventory; unsupported is the VVP target flag ceiling. Per-entry exact commands, current logs, diagnostics, image hashes and outcome classifications are in `unit-census-results.json`; the runner is `run_unit_compile_census.py`.

Three bounded, checker-bearing unit runtimes were freshly compiled and run under this exact Icarus/VVP pair:

| Test | Runtime result | Check evidence |
| --- | --- | --- |
| Adams Bridge `power2round_tb` | PASS | Exit 0, `TESTCASE PASSED`, 2048 cases completed, no fail/error marker. The upstream generator ran from a local `python` shim in the isolated runtime directory and generated fresh vectors. The only stderr line is Icarus’ warning that the testbench ignores `$system()`’s return value. |
| Adams Bridge pristine `rej_bounded_tb` | FAIL | Exit 0, `TESTCASE FAILED`, 64 queue-underflow reports, 0 output mismatches. Used the unchanged first-100 seed/vector fixtures and `+VEC_CNT=100`; no overlay. |
| Caliptra `csrng_tb` | PASS | Exit 0, `TESTCASE PASSED`, no fail marker, mismatch, fatal, or error line; the testbench pass path requires `error_ctr == 0`. Used only the previously documented package-first and missing-include-dir correction in a disposable filelist; pinned sources/testbench remained unchanged. Its printed `00 test cases` is not a tested-case count because `tc_ctr` is not incremented. |

Thus this bounded subset is **2 runtime PASS / 3 attempted**. It is not a full-suite pass rate: the remaining compile-pass benches have runtime **UNRUN** here, and the released 52-case Caliptra L0 runtime remains **0 attempted / 52**. Per-run commands, elapsed time, logs, marker counts, source/filelist hashes and image hashes are in `bounded-unit-runtime-results.json` and the `runtime/` subdirectories.

The initial top invocation without the required default-timescale command-file option is preserved as `top_no_timescale_*`; it adds an unrelated zero-delay clock diagnostic and is not the baseline result. A first partial unit census with a missing `ADAMSBRIDGE_ROOT` variable and first unit-runtime attempts without the local `python` shim on `PATH` are preserved under `unit-census-first-attempt-missing-abr-root*` and `runtime/*_first_missing_*`; these are superseded by the final runs. The final 44-entry result uses the correct root and reproduces the frozen inventory's compile counts.

No compiler, build/install, pinned source, manifest, tracker, or test checker was changed. All new outputs are in this evidence directory.

After the guarded-distribution follow-up was rebuilt, the same three prebuilt
unit images were rerun under final VVP SHA-256
`e9b7a64a8643973c9bc6597ca604285bbd718cf733e45181f6155390d9fdc8c6`.
The [runtime-only replay](final-vvp-e9b7a64a-20260923/summary.json) retains
the same **2 PASS / 1 FAIL** verdict with explicit check markers. The 44-entry
compile census and top compile use the unchanged compiler; no L0 runtime was
unblocked by this VVP update.
