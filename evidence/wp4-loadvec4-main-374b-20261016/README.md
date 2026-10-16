# WP4 `vpip_vec4_to_int64_saturated` remeasurement

Pinned measurement base: `374b037e7c8fba7097e0b86b05be7956ca6b5487`.

This requalifies the fused A/B-plane conversion on the current main pin after
#593 and #599. Reference and candidate were built from the same pinned source;
no rebase occurred during measurement. The profile selected this path for
screening: `of_LOAD_VEC4` accounted for 14.70% inclusive / 8.60% self samples,
and the converter for 9.79% inclusive / 9.91% self in the bounded Caliptra
part-select path. The profile stops intentionally at mcycle 5,000 and is not a
firmware pass.

## Instruction screen

The 100,000-access focused Callgrind run reduced whole-process instructions
from 2,342,064,005 to 1,861,103,335 (−20.535761%). Reference and candidate
stdout matched. The final wide-index fixture passed on both builds, including all 65,280
8-bit X/Z patterns plus signed and unsigned conversion, saturation, and a
65-bit tail; see [`exhaustive-edge/README.md`](exhaustive-edge/README.md).
See [`build-screen/README.md`](build-screen/README.md) for build provenance,
raw profiles, checksums, and logs.

The broad Callgrind screen covered 18 workloads. All exit codes were zero, all
18 outputs matched, and no non-target instruction count regressed by 2% or
more. The largest positive changes were `uvm_traffic` at +0.000684% and
`uvm_config_factory` at +0.000331%. The complete table and raw group profiles
are in [`corpus-screen/README.md`](corpus-screen/README.md); the combined CSV
is [`corpus-screen/instruction-counts.csv`](corpus-screen/instruction-counts.csv).

The focused and broad instruction gates and full pinned-base correctness gates
pass. Slurm job 1733 passed `make check`, FPGA target installation, the full
ivtest gate (including JSON), a standalone JSON replay, and real-DPI UVM. Both
JSON runs reported 4,676/4,676; UVM reported 367/0/0. The candidate's final
three-run wall table is recorded in job 1758; exact-head CI will run after the
PR opens. Its 18 outputs match. `waveform_fst` is 7.55% slower with a
7.22% candidate spread; wall time is supporting evidence and does not override
the instruction-count gate. See [`full-gates/README.md`](full-gates/README.md)
and [`final-wall/job-1758/wall-summary.md`](final-wall/job-1758/wall-summary.md).

## Profile and attempts

The single-CPU `perf record` profile used A2's
`smoke_test_dma_aes_gcm_short_1_dword`, bounded to mcycle 100–5000. It ran for
523.413 seconds (4,900 cycles, about 9.36 cycles/s), captured 53K task-clock
samples with zero lost, and reached 1,852,360 KiB peak RSS. `of_LOAD_VEC4`'s
`vec4_value` path accounted for 5.42% inclusive samples. Inputs, binaries,
submodule pins, the gzip-compressed raw profile, and runner logs are preserved in
[`profiles/main/`](profiles/main/).

- Job 1615 stopped before simulation because its output directory already
  existed; it supplied no measurement.
- Job 1619 built both sides and passed the edge fixture, then stopped on an
  invalid byte-identity check for generated `.vvp` files. Runtime outputs were
  the relevant comparison; the failed harness attempt is preserved under
  [`attempt-1619/`](attempt-1619/).
- Job 1620 completed the focused screen and edge comparison.
- Job 1621 completed the broad four-group instruction screen. The captured
  archive SHA256 is recorded in `corpus-screen/archive.sha256`.
