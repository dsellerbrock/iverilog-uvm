# Final paired wall medians — Slurm job 1277

Pinned measurement base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.
The single Slurm job used one CPU, two warm-ups and three interleaved measured
pairs per workload. No other A5 Slurm job was active during this run. All 18
workloads completed with byte-identical reference and candidate outputs.

Wall spread is `(maximum − minimum) / median × 100`. The final table is
supporting timing evidence; instruction counts remain the qualification gate.
Spreads above 5% are reported as measured.

| Workload | Reference median s (spread) | Candidate median s (spread) | Change |
| --- | ---: | ---: | ---: |
| behav | 5.928019 (5.00%) | 3.770681 (0.07%) | -36.39% |
| classq | 5.977843 (2.53%) | 5.626555 (2.67%) | -5.88% |
| fork_heavy | 0.415969 (0.53%) | 0.414479 (0.71%) | -0.36% |
| gate_strength | 1.466862 (0.10%) | 1.566095 (3.23%) | +6.76% |
| io_text | 0.113693 (0.02%) | 0.113778 (1.21%) | +0.07% |
| large_memory | 0.113691 (0.02%) | 0.113691 (0.01%) | +0.00% |
| multi_clock | 0.314017 (0.47%) | 0.315441 (0.75%) | +0.45% |
| randomize_dv_txn | 5.073936 (6.82%) | 5.076970 (0.95%) | +0.06% |
| randomize_z3 | 1.417830 (3.53%) | 1.416334 (0.12%) | -0.11% |
| rtl_alu | 3.819177 (1.36%) | 3.871143 (3.91%) | +1.36% |
| rtl_pipe | 7.175415 (0.71%) | 7.226058 (0.68%) | +0.71% |
| strings_aa_queue | 3.320354 (7.57%) | 3.268958 (10.66%) | -1.55% |
| uvm_config_factory | 0.614723 (0.26%) | 0.616478 (0.61%) | +0.29% |
| uvm_traffic | 3.623939 (9.69%) | 3.525888 (1.41%) | -2.71% |
| vpi_callbacks | 5.328492 (4.85%) | 5.325003 (2.84%) | -0.07% |
| waveform_fst | 0.664619 (7.56%) | 0.666215 (8.04%) | +0.24% |
| waveform_vcd | 0.614516 (0.01%) | 0.614554 (0.24%) | +0.01% |
| wide_vectors | 0.265171 (0.51%) | 0.263894 (1.49%) | -0.48% |

The `behav` median fell 36.39%. `gate_strength` was 6.76% slower by wall
median, with 0.10% reference and 3.23% candidate spread; instruction counts
show no regression there. Preserve the wall difference as supporting evidence.

Raw JSON, checksum, runtime fingerprints, pinned-base marker, and Slurm log
are alongside this summary.
