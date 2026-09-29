# OpenTitan 49-target parallel runtime census — 2026-09-29

The pinned OpenTitan revision `a78922f14a8cc20c7ee569f322a04626f2ac6127` was cloned to a disposable source tree. The clone contains 46 named, hash-checked overlay operations across 59 files; its tracked diff SHA-256 is `893469cb66f606207fd1d6285ca85a8f029202cdd734d583a0b4f686661e01e9`. The pinned checkout was not edited. The compiler used the merged speedup build (`ivl` SHA-256 `2b24c2854756c53c8bd51d8d19906e820700a7fd0d34dbfe4d56de7f3befb0a4`; `vvp` SHA-256 `1e1e39c507b23bfd0a29121ba3317801d9a7181b1cc2a18943fa1fdada6baa7c`).

The single complete corpus used `--lane runtime --commercial-unsafe --jobs 3 --runtime-timeout 1800 --runtime-memory-mib 4096`. Three independent targets ran concurrently. The host has 10 logical cores and 24 GiB RAM; more simultaneous 4 GiB runtimes would exceed the safe memory budget, especially because the sampled footprint can overshoot a cap. Each `vvp` process itself uses one CPU core. The two Xbar replays below were run one at a time because they need about 12–13 GiB each.

| Raw status | Targets |
| --- | ---: |
| PASS | 18 |
| DEBT (completed checks with warnings) | 3 |
| RUNTIME_FAIL | 12 |
| RUNTIME_MEMORY_LIMIT | 9 |
| FAIL (compile) | 5 |
| MATRIX_ERROR | 1 |
| RUNTIME_TIMEOUT | 1 |
| **Total** | **49** |

Forty-three targets compiled in this run. The earlier 49-target census had 12 PASS, 5 DEBT, 5 RUNTIME_FAIL and 27 compile FAIL; compiler version, overlays and setup differ, so the difference is combined campaign progress rather than an isolated speedup measurement. The full 49-target suite is not passing.

## Selected follow-ups (separate from the raw 49 rows)

- **Xbar Main:** PASS at a 12 GiB cap, 131.7 s runtime, 12.84 GB peak physical footprint.
- **Xbar Peri:** PASS at a 16 GiB cap, 42.0 s runtime, 13.59 GB peak. It had exceeded both 4 and 12 GiB caps before the passing replay.
- **LC Control:** PASS at an 8 GiB cap, 78.2 s runtime, about 4.05 GiB peak.
- **Clock Manager:** PASS in a selected retry; the corpus row was a transient harness `MATRIX_ERROR`.
- **AES:** With `--native-pkg-config openssl`, all native DPI sources built and the UVM test printed `TEST PASSED CHECKS` with no UVM errors. The runner still reported `RUNTIME_FAIL` because it mistook the benign table line `has Configuration error: FALSE` for a runtime error. This is a classifier defect, not an AES DV failure.
- **Power Manager:** A separately selected named clock-activity checker patch removed the observed assertion and produced `TEST PASSED CHECKS`; status remains DEBT due a timescale warning introduced by that patch.
- **SPI Device passthrough:** The selected `+TESTNAME=readbasic` case printed `TEST PASSED CHECKS`, status DEBT from warnings. The corpus default had no selected test and remains `RUNTIME_FAIL`.
- **OTBN:** With libelf, a generated smoke ELF, and `REPO_TOP`, the selected replay compiled and ran to about 4 us, then aborted on `SVScoped::Error: No such SystemVerilog scope: otbn_model_step.dut.u_dmem`. The observed Icarus DPI scope/name implementation disagrees with the valid relative lookup in the testbench; OTBN has no DV pass.

Six of the nine raw memory-limited targets remain without a verdict: CSRNG, EDN, KMAC, OTP Control, ROM Control, and top Earlgrey Alert Handler. Guard termination makes VVP call `$finish`, so the resulting end-of-simulation UVM assertions are supervisor-induced and do not establish independent DUT failures. SPI Host compiled but timed out after 1,800 s at about 507 us simulated time, with no pass marker. The five compile blockers are Chip, Flash Controller, I2C, Ibex I-cache (duplicate package providers), and SPI TPM. Other runtime failures remain in `result.json` with exact diagnostics and logs.

`result.json` is the immutable full-corpus report, `result.md` its generated summary, `overlay-manifest.json` the patch provenance, `matrix-logs.tar.gz` the full run's setup/compile/DPI/runtime logs, and `selected/` holds the separate focused result records. Caliptra was not run.
