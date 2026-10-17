# WP4 remeasurement on current main

Pinned measurement base: 631b7a869faaa05216d8749224520227b4b23d43.
Candidate source tree: #601 merge snapshot 51987d3cccfe2ddb862eb01b9a7388eb687276c6.
Campaign base: f9f8e0a79f230f38da6cbb4445994ad1075ad531.

Main had seven changed vvp/ runtime files between the previous WP4 pin and
this snapshot, so the converter qualification is being deliberately repeated
on this base. The reference and candidate are checked out by exact commit on
DAN-DESKTOP; all submodules, configure flags, compiler, and dependencies are
shared. The job first builds both sides, then runs the candidate correctness
gates. It runs timings only after those gates pass.

The job repeated the 100,000-access wide-index Callgrind instruction screen,
the 18-workload output/instruction screen, and the final interleaved three-run
wall table. Caliptra-scale Callgrind was not used. The final wall suite ran in
the same isolated Slurm allocation after all correctness and instruction
checks; no other A5 Slurm job ran concurrently.

## Result

Slurm job 1955 completed with exit code 0 on DAN-DESKTOP, pinned to CPU 1
(4 allocated CPUs, 8 GiB). `make check`, FPGA install, the legacy ivtest gate,
the full JSON suite, and real-DPI UVM all returned 0. The focused converter
result is:

| Pinned base | Reference instructions | #601 candidate instructions | Change | Output |
| --- | ---: | ---: | ---: | --- |
| `631b7a869faaa05216d8749224520227b4b23d43` | 2,342,085,316 | 1,861,124,521 | −20.535580% | identical |

All 18 broad workloads matched output. Instruction counts were identical on
15 rows; `randomize_z3`, `uvm_config_factory`, and `uvm_traffic` changed by
0.000000%, 0.000330%, and 0.000684%, respectively, with no increase over
0.000684%.

The table reports all final three-run wall medians. Spread is
`(maximum − minimum) / median`; these timings are supporting evidence and the
larger spreads remain visible rather than being hidden.

| Workload | Reference median s (spread) | #601 median s (spread) | Candidate change |
| --- | ---: | ---: | ---: |
| behav | 3.768 (5.33%) | 3.718 (2.70%) | −1.33% |
| classq | 5.622 (8.89%) | 5.621 (0.89%) | −0.03% |
| fork_heavy | 0.515 (0.50%) | 0.516 (0.26%) | +0.26% |
| gate_strength | 1.666 (8.92%) | 1.666 (9.06%) | −0.01% |
| io_text | 0.114 (0.08%) | 0.114 (0.16%) | +0.02% |
| large_memory | 0.114 (1.36%) | 0.116 (46.09%) | +0.96% |
| multi_clock | 0.414 (12.45%) | 0.414 (12.41%) | −0.01% |
| randomize_dv_txn | 4.427 (0.09%) | 4.376 (1.19%) | −1.15% |
| randomize_z3 | 1.469 (0.20%) | 1.468 (0.13%) | −0.02% |
| rtl_alu | 3.869 (1.33%) | 3.869 (1.28%) | −0.01% |
| rtl_pipe | 7.223 (1.41%) | 7.227 (0.73%) | +0.05% |
| strings_aa_queue | 4.370 (2.27%) | 3.570 (22.48%) | −18.30% |
| uvm_config_factory | 0.665 (7.53%) | 0.665 (7.78%) | +0.02% |
| uvm_traffic | 3.524 (2.92%) | 3.622 (4.11%) | +2.80% |
| vpi_callbacks | 5.876 (12.02%) | 5.824 (5.16%) | −0.90% |
| waveform_fst | 0.716 (7.00%) | 0.765 (13.08%) | +6.78% |
| waveform_vcd | 0.616 (0.28%) | 0.615 (0.26%) | −0.26% |
| wide_vectors | 0.264 (0.01%) | 0.264 (0.62%) | +0.01% |

The executable log, per-row Callgrind data, raw three-run wall data, gate
statuses, and input hashes are in `results/results-bundle.tgz` (SHA-256
`2b09f9e16b38d342c00a7d4c19c02e0ce8905069718f6f351c24152641aa0af0`). The PR
branch was synced to this base by a merge; it was not rebased again.
