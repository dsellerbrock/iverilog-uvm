# WP3 Linux correctness gates

Pinned measurement base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.
Slurm job 1242 used the candidate source and UVM core listed in
[`environment.txt`](environment.txt). The candidate build, FPGA target
install, legacy ivtest gate, and real-DPI UVM regression all returned 0. The
full JSON suite reported the same 16 inherited failures as the reference and
returned 16, which made the aggregate job exit 1. Job 1246's paired baseline
comparison reran those 16 cases on both installs and found byte-identical
results with no candidate-only failures; see
[`../json-baseline-1246/README.md`](../json-baseline-1246/README.md).

`stage-status.tsv` and `job-exit-code` preserve the exact stage outcomes.
Selected gate logs and timings are included here; the JSON log is compressed.
