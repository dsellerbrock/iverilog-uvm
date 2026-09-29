# OpenTitan 49-target runtime census after compiler fixes — 2026-09-29

The complete pinned OpenTitan corpus now has **23 PASS out of 49**, compared with 18 PASS in the previous raw census. This is a functional result on one frozen compiler image, not a claim that all DV tests pass.

| Raw status | Targets |
| --- | ---: |
| PASS | 23 |
| DEBT | 3 |
| Compile FAIL | 4 |
| RUNTIME_FAIL | 9 |
| RUNTIME_MEMORY_LIMIT | 7 |
| RUNTIME_TIMEOUT | 2 |
| MATRIX_ERROR | 1 |
| **Total** | **49** |

The run uses pinned OpenTitan revision `a78922f14a8cc20c7ee569f322a04626f2ac6127` in a disposable source clone. Its tracked diff SHA-256 is `8b7ab0548494243f967d2cc4a07aafac6600de88a00504d671b18ab4549c7a1f`: the prior 46-operation overlay plus exact-hash Ibex package-provider and Flash foreach syntax patches. Compile-only Chip and SPI TPM patches were excluded. The installed compiler engine SHA-256 is `64fee51caec391de5e5667a97273cbac67b29553e4f2fa87a1e13f61b88a3316`; VVP is `5b9ed7a8ed8006a998b55c0bc42d035aa99ddeb9c1b3495fd0b4651cf23600c3`.

The runner used `--lane runtime --commercial-unsafe --jobs 3 --runtime-timeout 1800 --runtime-memory-mib 4096`, with OpenSSL and libelf native DPI builds. The merged interpreter speedups are in this image. Three independent simulations ran concurrently; each VVP process uses one CPU core. The host has 10 logical cores and 24 GiB RAM, so the 4 GiB process guards and other host load constrained concurrent target count. The full JSON regression separately used four shards. Both this and the previous corpus used the merged speedups; their wall times are not a speedup A/B measurement. The current run had substantial host contention and was slower on many same-test rows.

## Changes from the previous raw census

- AES, Clock Manager, KMAC, RV Timer, and SRAM Controller moved to PASS. RV Timer uses its corrected official smoke selection; SRAM's change reflects benign FuseSoC native-source warning classification. AES includes the OpenSSL DPI build and corrected false-positive runtime classifier.
- Ibex I-cache moved from compile FAIL to RUNTIME_TIMEOUT. It compiles with zero hard or semantic diagnostics and advances past `cfg.randomize()`, but its official 800–1,000-transaction smoke printed no DV pass banner before the 1,800-second cap.
- CSRNG moved from memory limit to a concrete packed class-property bounds assertion. SPI Device moved from RUNTIME_FAIL to DEBT with its corrected official smoke selection and five remaining semantic notices.
- Flash Controller hard errors fell from 17 to 4; I2C fell from 18 to 15. Both still fail compilation.
- Pwrmgr's raw `MATRIX_ERROR` was an `EPERM` before simulator launch. The separate same-image selected replay compiled cleanly and reproduced `EscClkStopEscTimeout_A` at 20,631,414 ps, so Pwrmgr still fails DV.

The remaining compile blockers are Chip (`std::randomize` and nested associative-array property), Flash (indexed class-property foreach and multidimensional solve-before), I2C (coverage bins and constraint support), and SPI TPM (stale testbench parameters). Runtime blockers include ADC and USBDEV config randomization, CSRNG's property assertion, Entropy Source's wide `$bitstoreal` call, HMAC's scoreboard mismatch, and OTBN's missing smoke ELF setup. The directed SPI rows need their own pass criteria or required test selection; a zero process exit alone does not qualify them. EDN, LC Control, OTP Control, ROM Control, both Xbars, and the top Alert Handler reached the 4 GiB guard. The guard-induced end-of-simulation TLUL errors are not independent DUT failures. SPI Host and Ibex timed out at 1,800 seconds.

`result.json` is the immutable 49-row report, `result.md` its generated summary, `source-manifest.json` records patch provenance, and `matrix-logs.tar.gz` holds setup, compiler, native-DPI, and runtime logs. `selected/` records separate Pwrmgr and real-ELF OTBN follow-ups; neither changes the raw counts. The previously recorded higher-memory Xbar and LC Control passes are also separate from this 4 GiB corpus. Caliptra was not run.
