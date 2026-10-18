# WP5 automatic-context live-list unlink

Pinned measurement base: `ca559fd97b19bd6a56cc10f0faf8583b4077975f`.

## Profile and change

The M3 current-main profile sampled `vthread_free_context` at 91.78% of
`fork_heavy`'s self samples. The function unlinked a context from
`scope->live_contexts` by scanning the live singly linked list. The candidate
stores the predecessor in the existing automatic-context record, updates that
link on allocation, and uses it for the normal release path. It verifies the
neighbor records before unlinking and retains the original scan/recovery path
when metadata cannot be validated.

This is a corpus speedup, not a claimed Caliptra optimization: the same
function accounted for only 0.02–0.03% of the three Caliptra profile samples.
Caliptra throughput still needs a direct candidate measurement.

## Pinned-base instruction screen

Reference and candidate were built from the same pinned source and run on the
same CPU. The candidate compiler emitted each `.vvp` program once; the same
program was run under both VVP binaries. Callgrind supplied deterministic
instruction totals, and the JSON runner checked output files byte-for-byte.
All 18 workload outputs matched. The target improved 46.171293%; the largest
other increase was 0.707240% (`uvm_traffic`), below the 2% limit.

| Workload | Reference instructions | Candidate instructions | Change | Output |
| --- | ---: | ---: | ---: | :---: |
| `behav` | 86,067,817,379 | 86,142,814,856 | +0.087138% | identical |
| `classq` | 120,678,274,817 | 120,880,473,440 | +0.167552% | identical |
| `fork_heavy` | 433,053,254 | 233,106,968 | **−46.171293%** | identical |
| `gate_strength` | 38,952,167,192 | 38,952,187,719 | +0.000053% | identical |
| `io_text` | 1,585,401,317 | 1,592,793,821 | +0.466286% | identical |
| `large_memory` | 3,050,778,898 | 3,050,778,961 | +0.000002% | identical |
| `multi_clock` | 8,544,222,398 | 8,544,223,320 | +0.000011% | identical |
| `randomize_dv_txn` | 42,335,524,184 | 42,333,867,327 | −0.003914% | identical |
| `randomize_z3` | 13,001,227,393 | 13,001,682,730 | +0.003502% | identical |
| `rtl_alu` | 104,999,985,519 | 105,000,033,992 | +0.000046% | identical |
| `rtl_pipe` | 207,780,756,787 | 207,780,779,256 | +0.000011% | identical |
| `strings_aa_queue` | 73,108,412,182 | 73,129,932,370 | +0.029436% | identical |
| `uvm_config_factory` | 6,177,123,866 | 6,178,497,537 | +0.022238% | identical |
| `uvm_traffic` | 40,681,193,398 | 40,968,907,038 | +0.707240% | identical |
| `vpi_callbacks` | 132,420,586,208 | 132,772,586,676 | +0.265820% | identical |
| `waveform_fst` | 14,172,750,460 | 14,194,751,220 | +0.155233% | identical |
| `waveform_vcd` | 14,508,085,075 | 14,552,085,848 | +0.303284% | identical |
| `wide_vectors` | 6,538,332,655 | 6,538,332,795 | +0.000002% | identical |

The machine-readable table, per-group JSON results, and compressed Callgrind
profiles are alongside this README under `screen/`. Slurm job 2331 ran the
three groups. Its core group's measurement completed and all six outputs
matched, but a post-measurement assertion expected five rows for the six-entry
group and set that array task's exit status to 1. The preserved
`postprocess-note.txt` and corrected CSV record the completed six profiles;
no workload was rerun or omitted.

## Correctness gates

Pinned-base Slurm job 2342 exited 0. The source and builds use base
`ca559fd97b19bd6a56cc10f0faf8583b4077975f`; the job applied only the
`vvp/vthread.cc` candidate patch. Stage results are in
[`gates/job2342/results/stage-status.tsv`](gates/job2342/results/stage-status.tsv),
with full logs and resource measurements in [`gates/job2342/`](gates/job2342/).

| Stage | Result |
| --- | --- |
| `make check` | passed |
| FPGA target install | passed |
| Legacy ivtest | 7,477 total; 7,472 passed, 0 failed, 2 not implemented, 3 expected failures |
| VPI | 133/133 passed |
| Negative | 152/152 passed |
| Runtime invariants | 15/15 passed |
| JSON ivtest | 4,718 ran, 0 failed |
| Real-DPI UVM | 367 passed, 0 failed, 0 skipped |

## Final wall-time support — Slurm job 2356

The reference and candidate were interleaved for three runs per workload on
one pinned CPU, with no other A5 Slurm job running. All 18 outputs matched
byte-for-byte in all three pairs. Medians and spreads use `(max - min) / median`.
The 7.44% reference spread for `waveform_fst` is retained as supporting data;
it does not affect the instruction-count screen.

| Workload | Reference median s (spread) | Candidate median s (spread) | Candidate change |
| --- | ---: | ---: | ---: |
| `behav` | 3.770 (1.37%) | 3.721 (1.37%) | -1.29% |
| `classq` | 5.773 (0.03%) | 5.774 (1.73%) | +0.01% |
| `fork_heavy` | 0.464 (0.03%) | 0.064 (0.04%) | **-86.29%** |
| `gate_strength` | 1.518 (0.10%) | 1.518 (0.26%) | +0.01% |
| `io_text` | 0.114 (0.10%) | 0.114 (0.01%) | +0.03% |
| `large_memory` | 0.114 (0.04%) | 0.114 (0.02%) | -0.03% |
| `multi_clock` | 0.314 (0.03%) | 0.314 (0.01%) | +0.01% |
| `randomize_dv_txn` | 3.725 (1.40%) | 4.375 (1.22%) | **+17.45%** |
| `randomize_z3` | 1.318 (3.74%) | 1.318 (3.90%) | -0.01% |
| `rtl_alu` | 3.971 (0.02%) | 3.971 (8.86%) | +0.00% |
| `rtl_pipe` | 7.476 (0.65%) | 7.376 (0.05%) | -1.33% |
| `strings_aa_queue` | 3.170 (4.72%) | 3.219 (4.69%) | +1.55% |
| `uvm_config_factory` | 0.618 (0.27%) | 0.618 (0.46%) | +0.02% |
| `uvm_traffic` | 3.422 (0.05%) | 3.522 (1.43%) | +2.93% |
| `vpi_callbacks` | 5.274 (0.04%) | 5.374 (4.69%) | +1.90% |
| `waveform_fst` | 0.668 (7.44%) | 0.717 (0.57%) | +7.38% |
| `waveform_vcd` | 0.614 (0.05%) | 0.614 (0.01%) | +0.01% |
| `wide_vectors` | 0.264 (0.01%) | 0.264 (0.02%) | +0.02% |

The stable `randomize_dv_txn` wall increase is not reflected in its Callgrind
instruction total (−0.003914%). Wall time is supporting evidence; the
instruction screen remains the qualification gate. No Caliptra gain is
claimed for WP5: the main profile sampled `vthread_free_context` at only
0.02–0.03% there. Raw per-run data, binary hashes, and the exact job script
are in [`wall-job2356/`](wall-job2356/).

The M3 current-main profile is in
[`../m3-current-main-profile-20261017/README.md`](../m3-current-main-profile-20261017/README.md).
