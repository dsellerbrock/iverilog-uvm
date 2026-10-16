# Pinned predecode three-run wall-time support table

Pinned base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.

Slurm job 1444 ran three interleaved reference/candidate samples for each of
the 18 `sim-hotspots` workloads on one CPU, with no other A5 job running.
All three output pairs matched byte-for-byte, including VCD and FST artifacts.
The medians and `(max - min) / median` spreads are in
`results/wall-summary.csv`; raw per-run measurements and hashes are in
`results/sim-hotspots-wall.json`.

Several short workloads have wide spreads (the largest candidate spread is
43.445690%). Per the campaign instruction, these are reported as supporting
data and do not block the instruction-count gate. The separate Callgrind
screen shows no non-target instruction increase above 0.038453%.
