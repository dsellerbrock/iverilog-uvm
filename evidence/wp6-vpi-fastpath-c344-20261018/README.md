# WP6 remeasurement after the runtime-path change

WP6's pinned measurement base remains `d9caaaea5b410ed14e7ca14be828fc2f2c9fea44`.
Its single pre-merge rebase was already used at that base. The required
`d9caaaea..origin/main` diff now touches ten `vvp/` files, so this is the one
deliberate remeasurement on current main `c344d20197a569dea8936bad95de3d185b1e78dc`;
the PR branch is not rebased again.

The candidate is the same two-file WP6 change from #658 applied to clean
`c344d201` sources. Its exact patch is `input/candidate.patch` (SHA-256
`61047cc299d43f5b76a31ddc91622e475f0ef57c8ef0d9cc326ab4445d26ca35`). Both
sides use the same Linux toolchain flags and pinned UVM submodules. The focused
VPI semantic fixture must match before the 18-workload Callgrind screen runs.

Slurm build job 2723 succeeded, including the focused VPI semantic fixture.
Callgrind attempt 2724 failed before measurement because its guard used the
WP13 build-marker path. Attempt 2728 corrected that path but placed the runner
outside `benchmarks/sim-hotspots`, so the harness could not find its inputs;
both failures produced no measurements and are preserved under `attempts/`.
Attempt r3 keeps the runner beside the corpus sources and uses hard-linked,
immutable copies of the successful c344 build products in its own run tree.
Slurm build job 2723 passed the focused VPI semantic fixture. Callgrind array
job 2734 completed all three groups on c344: all 18 outputs match byte for
byte; `vpi_callbacks` fell 14.356178% (132,068,589,049 → 113,108,587,052).
The largest other instruction increase rounds to +0.000001% (`randomize_z3`);
`strings_aa_queue` improved 2.137685%. The full CSV/JSON results, compressed
profiles, and local checksums are in [`attempts/job-2734/`](attempts/job-2734/).
## Current-main correctness gate — Slurm job 2768

All five stages passed on c344: VPI semantics, `make check`, FPGA target
install, the full `.github/ivtest_gate.sh`, and real-DPI UVM. Results were
7,523 legacy tests with 0 failures (2 not implemented, 3 expected failures),
VPI 133/133, negative 152/152, runtime invariants 15/15, JSON 4,762/4,762,
and UVM 367/367. Stage codes, logs, and checksums are preserved in
[`attempts/job-2768/`](attempts/job-2768/).

## Isolated current-main wall-time support — Slurm job 2811

Three interleaved runs per side were pinned to one CPU with no other A5 Slurm
job active. The runner verified byte-identical outputs on all 18 workloads.
`vpi_callbacks` improved from a 5.122656 s reference median to a 4.322061 s
candidate median (1.185234x); reference/candidate spreads were 0.038%/1.234%.
Instruction counts are the promotion gate; wall time is supporting evidence.
The largest reference spread was 12.484% (`rtl_alu`), and the largest
candidate spread was 8.004% (`uvm_config_factory`). They are reported rather
than used to block the instruction-count pass.

| Workload | Reference median (spread) | Candidate median (spread) | Ref/candidate |
| --- | ---: | ---: | ---: |
| `behav` | 3.771798s (0.031%) | 3.771509s (0.004%) | 1.000077x |
| `classq` | 5.774065s (1.720%) | 5.723678s (1.762%) | 1.008803x |
| `fork_heavy` | 0.063628s (0.052%) | 0.063722s (0.239%) | 0.998519x |
| `gate_strength` | 1.518350s (6.536%) | 1.517861s (0.107%) | 1.000322x |
| `io_text` | 0.113712s (0.102%) | 0.063592s (0.099%) | 1.788162x |
| `large_memory` | 0.113663s (0.040%) | 0.113649s (0.019%) | 1.000128x |
| `multi_clock` | 0.313937s (0.027%) | 0.313925s (0.022%) | 1.000039x |
| `randomize_dv_txn` | 4.426917s (1.158%) | 4.428169s (0.012%) | 0.999717x |
| `randomize_z3` | 1.267972s (4.132%) | 1.267720s (0.043%) | 1.000199x |
| `rtl_alu` | 4.023248s (12.484%) | 3.972711s (1.280%) | 1.012721x |
| `rtl_pipe` | 7.427246s (1.335%) | 7.381642s (0.674%) | 1.006178x |
| `strings_aa_queue` | 3.170215s (4.819%) | 3.119640s (0.021%) | 1.016212x |
| `uvm_config_factory` | 0.614681s (8.731%) | 0.614569s (8.004%) | 1.000182x |
| `uvm_traffic` | 3.572707s (2.875%) | 3.572693s (1.427%) | 1.000004x |
| `vpi_callbacks` | 5.122656s (0.038%) | 4.322061s (1.234%) | 1.185234x |
| `waveform_fst` | 0.671301s (7.079%) | 0.667111s (0.404%) | 1.006281x |
| `waveform_vcd` | 0.614550s (0.536%) | 0.614535s (0.312%) | 1.000023x |
| `wide_vectors` | 0.263895s (0.025%) | 0.263923s (0.027%) | 0.999891x |

The complete raw JSON, CSV, runner hash, environment, and checksums are in
[`attempts/job-2811/final-wall-c344-r2/`](attempts/job-2811/final-wall-c344-r2/).
Setup attempt 2810 stopped before collecting samples because the runner was
not staged beside the benchmark sources; its failure output is preserved in
[`attempts/job-2810/`](attempts/job-2810/). Earlier pinned evidence remains in
[`wp6-vpi-fastpath-d9caa-20261018`](../wp6-vpi-fastpath-d9caa-20261018/README.md).
