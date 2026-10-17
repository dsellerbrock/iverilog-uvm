# WP4 broad Callgrind instruction screen

Pinned base: `374b037e7c8fba7097e0b86b05be7956ca6b5487`. Slurm array job 1621 ran four isolated groups (core, vectors, mixed, FST); each row compares reference and candidate from that same base.

All 18 workloads exited zero and produced identical output. The largest positive instruction change is `uvm_traffic` at +0.000684%; the next is `uvm_config_factory` at +0.000331%. No non-target workload regressed by 2% or more.

| Workload | Reference Ir | Candidate Ir | Delta | Output |
| --- | ---: | ---: | ---: | :---: |
| behav | 81,326,623,413 | 81,326,623,413 | +0.000000% | yes |
| classq | 115,610,920,624 | 115,610,920,624 | +0.000000% | yes |
| fork_heavy | 426,720,479 | 426,720,479 | +0.000000% | yes |
| gate_strength | 37,417,014,933 | 37,417,014,933 | +0.000000% | yes |
| io_text | 1,548,437,110 | 1,548,437,110 | +0.000000% | yes |
| large_memory | 2,911,411,539 | 2,911,411,539 | +0.000000% | yes |
| multi_clock | 8,196,412,983 | 8,196,412,983 | +0.000000% | yes |
| randomize_dv_txn | 42,413,468,726 | 42,413,468,726 | +0.000000% | yes |
| randomize_z3 | 12,994,949,294 | 12,994,949,132 | -0.000001% | yes |
| rtl_alu | 100,508,829,560 | 100,508,829,560 | +0.000000% | yes |
| rtl_pipe | 199,224,537,083 | 199,224,537,083 | +0.000000% | yes |
| strings_aa_queue | 71,462,378,513 | 71,462,378,513 | +0.000000% | yes |
| uvm_config_factory | 6,033,648,486 | 6,033,668,454 | +0.000331% | yes |
| uvm_traffic | 39,413,792,823 | 39,414,062,287 | +0.000684% | yes |
| vpi_callbacks | 127,940,583,230 | 127,940,583,230 | +0.000000% | yes |
| waveform_fst | 13,756,744,511 | 13,756,744,467 | -0.000000% | yes |
| waveform_vcd | 14,020,079,129 | 14,020,079,129 | +0.000000% | yes |
| wide_vectors | 6,467,875,187 | 6,467,875,187 | +0.000000% | yes |

Per-group provenance, raw Callgrind files, runner logs, and checksum manifests are retained in the four subdirectories. The full combined data is [`instruction-counts.csv`](instruction-counts.csv); the transferred archive hash is in [`archive.sha256`](archive.sha256).
