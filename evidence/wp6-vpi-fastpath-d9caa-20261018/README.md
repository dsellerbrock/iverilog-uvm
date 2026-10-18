# WP6 post-rebase measurements

Measurement base: `d9caaaea5b410ed14e7ca14be828fc2f2c9fea44`.
Candidate source commit: `498bf0826b810d5fe8ae560b02903c7bb5558c36`.

This deliberate remeasurement follows the single pre-merge rebase. The required
`ca559..origin/main` runtime-path diff touched only `vvp/vthread.cc` (48 lines
from #640), so the original pinned-base result remains recorded separately at
[`wp6-vpi-fastpath-ca559-20261018`](../wp6-vpi-fastpath-ca559-20261018/README.md)
and is not substituted for this new-base evidence.

The candidate patch contains only `vvp/vpi_priv.cc` and `vvp/vpi_tasks.cc`;
its SHA-256 and the exact base/submodule archive hashes are in
[`input/source-inputs.sha256`](input/source-inputs.sha256). The compressed
source snapshot excludes only documentation, evidence, and `.ai` metadata; it
includes the runtime, benchmark corpus, test suites, and three pinned UVM
submodules.

Build attempt 2617 stopped before compilation because the shared Slurm Git
cache could not transition cleanly from `ca559fd` across #640; the preserved
failure record is [here](attempts/build-2617/FAILURE.md). Archive-based build
job 2618 succeeded for both the `d9caaaea` reference and the VPI candidate.
Its binary hashes and complete logs are in
[`attempts/build-2618`](attempts/build-2618/).

## New-base Callgrind screen — Slurm array job 2622

The 18-workload screen used the same `ca559` candidate patch on the exact
`d9caaaea` reference and candidate builds. `vpi_callbacks` fell from
132,420,586,674 to 113,812,582,295 instructions (−14.052199%). Every other
workload stayed within the +2% regression cap; the largest increase was
`waveform_vcd` at +0.303238%. `io_text` also improved by 6.170611% and
`strings_aa_queue` by 2.105741%. All outputs matched in the Callgrind runner
except `waveform_fst`, which the isolated wall runner checks separately.
The complete base-tagged table is [`instruction-counts.csv`](instruction-counts.csv);
group outputs, per-run provenance, and checksums are under
[`attempts/callgrind`](attempts/callgrind/).

## New-base correctness gate — Slurm job 2625

All five stages passed: VPI integer conversion semantics, `make check`, FPGA
install, `.github/ivtest_gate.sh`, and real-DPI UVM. The gate reported 7,472
legacy tests passed with 0 failed (2 not implemented and 3 expected failures),
VPI 133/133, negative tests 152/152, runtime invariants 15/15, JSON ivtest
4,718/4,718, and UVM 367/367. Stage exit codes and logs are preserved in
[`attempts/gates`](attempts/gates/).

The source-only archive omits documentation, so job 2625's first
`.github/ivtest_gate.sh` invocation logged that its tracked expected-fail
manifest was absent. To verify the name-diff check with its input present, job
2630 copied the exact manifest from `d9caaaea` (SHA-256
`b22c9f7b117ea0b1644155c2673f27944da404a7b92c0f52a50998f29712c357`) and
reran the entire gate. It passed: 7,477 legacy tests (0 failed), a clean
expected-failure name diff, VPI 133/133, negative 152/152, runtime invariants
15/15, and JSON 4,718/4,718. The replay log, input, script, and provenance are
preserved under [`attempts/ivtest-expect-list-replay-2630`](attempts/ivtest-expect-list-replay-2630/).

## Isolated wall-time support — Slurm job 2629

Three interleaved runs were pinned to one CPU after all other A5 Slurm jobs
had finished. The runner verified byte-identical output for all 18 workloads.
`vpi_callbacks` improved from a 5.373551 s reference median to a 4.571550 s
candidate median (1.175433x; 0.956% reference spread and 0.024% candidate
spread). The instruction-count screen is the promotion gate; wall time is
supporting evidence. The largest candidate spread was 6.367% on
`strings_aa_queue`, which remains reported here and does not change the
instruction gate.

Full three-run medians and spreads:

| Workload | Reference median (spread) | Candidate median (spread) | Ref/candidate |
| --- | ---: | ---: | ---: |
| `behav` | 3.721465s (0.026%) | 3.719978s (0.046%) | 1.000400x |
| `classq` | 5.822875s (0.029%) | 5.873531s (2.566%) | 0.991375x |
| `fork_heavy` | 0.063641s (0.104%) | 0.063634s (0.030%) | 1.000113x |
| `gate_strength` | 1.517453s (0.161%) | 1.518367s (3.181%) | 0.999398x |
| `io_text` | 0.113627s (0.063%) | 0.063615s (0.149%) | 1.786168x |
| `large_memory` | 0.113643s (0.020%) | 0.113658s (0.013%) | 0.999864x |
| `multi_clock` | 0.313886s (0.003%) | 0.313900s (0.016%) | 0.999956x |
| `randomize_dv_txn` | 4.425422s (1.184%) | 4.426595s (1.154%) | 0.999735x |
| `randomize_z3` | 1.317761s (0.025%) | 1.318911s (0.152%) | 0.999128x |
| `rtl_alu` | 3.971296s (1.272%) | 3.971705s (0.016%) | 0.999897x |
| `rtl_pipe` | 7.425057s (0.674%) | 7.476165s (1.311%) | 0.993164x |
| `strings_aa_queue` | 3.220053s (0.119%) | 3.169659s (6.367%) | 1.015899x |
| `uvm_config_factory` | 0.617607s (0.026%) | 0.617612s (0.034%) | 0.999993x |
| `uvm_traffic` | 3.573099s (2.767%) | 3.521554s (1.437%) | 1.014637x |
| `vpi_callbacks` | 5.373551s (0.956%) | 4.571550s (0.024%) | 1.175433x |
| `waveform_fst` | 0.714545s (0.006%) | 0.714546s (0.005%) | 0.999999x |
| `waveform_vcd` | 0.614434s (0.372%) | 0.614452s (0.005%) | 0.999970x |
| `wide_vectors` | 0.263834s (0.014%) | 0.263823s (0.016%) | 1.000041x |

Raw JSON, CSV, environment, checksums, and job output are in
[`attempts/final-wall-2629`](attempts/final-wall-2629/).
