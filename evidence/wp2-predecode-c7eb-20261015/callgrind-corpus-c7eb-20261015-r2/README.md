# Pinned predecode Callgrind corpus screen

Pinned base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.

Slurm job 1423 ran one interleaved reference/candidate pair for each of the
18 `sim-hotspots` workloads on one CPU, with Valgrind 3.26.0 and
`--fair-sched=yes`. Both runtimes used the same compiled benchmark image. The
candidate source hashes match the code measured in Caliptra job 1420.

All 18 outputs matched byte-for-byte. The largest non-target instruction
increase was `uvm_config_factory` at +0.038453%, below the 2% regression cap.
Full counts are in `results/instruction-counts.csv`; compressed profiles,
output hashes, and the full runner JSON are also retained under `results/`.
The `summary:` field is the positive Callgrind instruction total for each
workload.

A first setup attempt, job 1422, failed before profiling because its Valgrind
path omitted the run suffix. It produced no measurement; see r1.
