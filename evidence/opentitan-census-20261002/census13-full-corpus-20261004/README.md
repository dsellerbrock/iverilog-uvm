# OpenTitan census13: coherent 49-target result

## Result

One runtime-lane invocation completed all 49 targets with **49 PASS**. Every
row has zero setup/compile failures, hard errors, semantic debt, runtime errors,
runtime debt, timeouts, and memory-cap hits; all 49 emitted the runtime pass
banner.

| Measure | Result |
|---|---:|
| Targets | 49 / 49 |
| PASS | 49 |
| Hard errors / semantic debt | 0 / 0 |
| Runtime errors / runtime debt | 0 / 0 |
| Setup or compile failures | 0 |
| Runtime timeouts / memory-cap hits | 0 / 0 |
| Sum of per-row runtime durations | 14,103.678 s (3 h 55 m; aggregate, not wall time) |
| Per-process runtime limit | 18,000 s (5 h) |
| Per-process memory limit | 9,536 MiB |

The slowest rows were:

| Core | Runtime | Peak physical footprint |
|---|---:|---:|
| `lowrisc:dv:flash_ctrl_sim:0.1` | 6,674.724 s (1 h 51 m) | 1,365,329,360 bytes |
| `lowrisc:dv:spi_host_sim:1.0` | 1,466.303 s | 806,552,536 bytes |
| `lowrisc:dv:i2c_sim:0.1` | 918.347 s | 667,485,072 bytes |
| `lowrisc:dv:spi_device_sim:0.1` | 784.116 s | 557,531,952 bytes |
| `lowrisc:opentitan:top_earlgrey_alert_handler_sim:0.1` | 563.029 s | 790,512,624 bytes |
| `lowrisc:dv:sram_ctrl_sim:0.1` | 374.372 s | 216,400,448 bytes |
| `lowrisc:dv:chip_sim:0.1` | 337.661 s | 3,107,523,272 bytes |

The largest observed footprint was 3,107,523,272 bytes, below the configured
per-process cap. Flash passed within its five-hour limit.

## Reproduction and provenance

The exact command is [run-census13-coherent.sh](run-census13-coherent.sh).
The run used two jobs, 600-second setup/compile limits, the runtime and memory
limits above, `-gcommercial-unsafe`, UVM 1.2, native OpenSSL/libelf, and xPack
RV32 assembler/linker tools for OTBN. Tool hashes and patch preflight output
are in [preflight.log](preflight.log).

The disposable OpenTitan source snapshot was prepared from pinned revision
`a78922f14a8cc20c7ee569f322a04626f2ac6127` with the OTP covergroup-purity,
Flash element-wise solve-before, and SPI-TPM SRAM/reset compatibility patches.
The preflight reverse-dry-run confirmed all three patches were present. The
runner reports `opentitan_revision: unknown` and `opentitan_dirty: true`: this
snapshot has no discoverable Git metadata and contains those local overlays.
The pinned source checkout was not modified.

The compiler engine SHA-256 was
`8dae711b38f7229b74b29455db587238ef76452928a66faeb5085aa429ef184c`; the VVP
runtime SHA-256 was
`2dee1367fb1c984aa8e77d58ddd6f87808b39489d2862fe9bf03e78f1739f570`.

Full results: [result-census13.md](result-census13.md) and
[result-census13.json](result-census13.json).

## Hot-path follow-through

The detailed profile analysis is in
[`HOTPATHS.md`](../census12-full-corpus-20261003/HOTPATHS.md). The census13
runtime and compiler hashes match the profiles collected during census12.
Every one of the 27 census13 targets taking more than 30 seconds has at least
one native sample capture in the existing profile set; it contains 61 unique
native-sample capture names across 27 targets, plus Xcode Time Profiler traces
for SRAM, SPI host, and SPI device. The profiles identify the Flash
associative-array successor walk, repeated Z3 enumeration, backdoor/VPI reads,
four-state resolution, SVA/VPI callbacks, and object/context bookkeeping as
the main measured paths. These samples are phase snapshots, not whole-run CPU
percentages; the 22 shorter targets were not comprehensively sampled.
