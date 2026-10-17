# Final three-run wall medians — Slurm job 1758

Pinned base: `374b037e7c8fba7097e0b86b05be7956ca6b5487`. One CPU; two warm-ups and three interleaved measured reference/candidate pairs per workload, all in one Slurm job. No other A5 Slurm job was active. All 18 workloads matched output in all measured runs. The table is supporting timing evidence; the instruction counts are the qualification gate. Spread is `(max − min) / median × 100`, and values above 5% are retained as measured.

| Workload | Reference median s (spread) | Candidate median s (spread) | Change |
| --- | ---: | ---: | ---: |
| behav | 3.670911 (1.39%) | 3.671048 (0.13%) | +0.00% |
| classq | 5.570565 (1.73%) | 5.525635 (0.93%) | -0.81% |
| fork_heavy | 0.464241 (0.01%) | 0.464224 (0.25%) | -0.00% |
| gate_strength | 1.466612 (0.08%) | 1.466681 (0.24%) | +0.00% |
| io_text | 0.113789 (1.12%) | 0.113690 (0.18%) | -0.09% |
| large_memory | 0.113704 (0.07%) | 0.114866 (1.06%) | +1.02% |
| multi_clock | 0.314041 (0.43%) | 0.315122 (0.33%) | +0.34% |
| randomize_dv_txn | 4.627008 (1.10%) | 4.576236 (1.16%) | -1.10% |
| randomize_z3 | 1.368708 (0.19%) | 1.369604 (0.08%) | +0.07% |
| rtl_alu | 3.874561 (2.61%) | 3.871764 (1.33%) | -0.07% |
| rtl_pipe | 7.228121 (11.10%) | 7.280022 (1.39%) | +0.72% |
| strings_aa_queue | 3.317604 (1.51%) | 3.117455 (0.01%) | -6.03% |
| uvm_config_factory | 0.616007 (0.22%) | 0.614705 (0.56%) | -0.21% |
| uvm_traffic | 3.423062 (1.46%) | 3.469490 (1.47%) | +1.36% |
| vpi_callbacks | 5.121510 (0.97%) | 5.169837 (0.97%) | +0.94% |
| waveform_fst | 0.664644 (0.21%) | 0.714796 (7.22%) | +7.55% |
| waveform_vcd | 0.614544 (0.02%) | 0.614628 (0.64%) | +0.01% |
| wide_vectors | 0.263874 (0.03%) | 0.263844 (0.06%) | -0.01% |

The `waveform_fst` candidate median is 7.55% slower, with 7.22% candidate spread; retain this wall observation without blocking the instruction-count pass. Raw JSON, environment fingerprints, runner hash, and checksum are beside this table.
