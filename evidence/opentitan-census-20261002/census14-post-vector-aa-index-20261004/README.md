# OpenTitan census14 after associative-array indexing

## Result

The two-job runtime matrix passed **49/49 selected targets**. All rows had zero
setup or compile failures, hard errors, semantic debt, runtime errors, runtime
debt, timeouts, or memory-cap hits; every row emitted its pass banner.

| Measure | Result |
|---|---:|
| Runtime targets | 49 / 49 |
| Sum of target runtimes | 15,675.919 s (4 h 21 m aggregate, not wall time) |
| Per-target runtime limit | 18,000 s (5 h) |
| Per-process memory cap | 9,536 MiB |
| Largest recorded footprint | 3,272,559,280 bytes (`chip_sim`) |

The longest rows were Flash at 5,756.067 s (1 h 35 m), SPI host at 2,054.366 s,
I2C at 1,350.549 s, SPI device at 1,037.483 s, and Alert Handler at 658.767 s.
The machine was also running the separate worker's CPU-intensive simulation,
so these matrix durations are host-contended measurements. Use the dedicated
same-input Flash comparison in the [reproducer guide](../../../benchmarks/opentitan-hotpaths/README.md)
for the isolated before/after timing.

## Provenance and reproduction

The run used the indexed VVP runtime
`105caac4cc9d56ddba0fdd08b4d7672735bcfdc4d2ad606e11790dc5d17315fe` and
compiler engine `8dae711b38f7229b74b29455db587238ef76452928a66faeb5085aa429ef184c`.
It used UVM 1.2, `-gcommercial-unsafe`, two matrix jobs, a 5-hour runtime limit,
and a 9,536-MiB memory cap.

The disposable source snapshot was copied from pinned OpenTitan revision
`a78922f14a8cc20c7ee569f322a04626f2ac6127` and carried the three documented
OTP, Flash solve-order, and SPI-TPM wiring overlays. Its copied checkout has no
Git metadata; the matrix therefore records the revision as `unknown` and the
source as dirty. The preflight log records successful reverse dry-runs of all
three patches. The pinned source checkout was left unchanged.

The [top-level reproduction guide](../../../docs/conformance/opentitan_49of49_reproduction.md)
has copyable setup and parallel-run commands. The archived
[run script](run-census14-post-index.sh) contains the exact machine-local
invocation used here. Full rows and fingerprints are in
[result-census14.md](result-census14.md) and
[result-census14.json](result-census14.json); patch preflight is in
[preflight.log](preflight.log).

## Hot-path follow-through

The [ranked hot-path report](../census12-full-corpus-20261003/HOTPATHS.md)
now includes profiles from this indexed-runtime census. Selected native
samples are gzip-compressed in this directory and can be read with
`gzip -dc <capture.sample.txt.gz>`. They are 10-second phase snapshots with
inclusive stack counts, not whole-run CPU percentages.
