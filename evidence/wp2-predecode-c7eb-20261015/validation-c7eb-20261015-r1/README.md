# Pinned predecode correctness and output screen

Pinned base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.

Slurm job 1421 used the candidate install from the Caliptra screen after
verifying the four changed VVP source hashes and all three install binary
hashes. It requested one CPU and 4 GiB. The regression overlay added the new
four-state test to both legacy and JSON manifests.

Results:

- `ci/run-smoke.sh`: passed.
- Focused property-index legacy list: 19/19 passed.
- Focused property-index JSON list: 19/19 passed.
- One paired output run over all 18 `sim-hotspots` workloads: all outputs
  matched, including VCD and FST files.

The JSON benchmark runner reported `perf_stat_available=true` but no
instruction event values. Use the separate Callgrind screen for instruction
counts. This run was an output check, not timing evidence. The dedicated
malformed-metadata smoke script was added afterward and passed separately in
job 1449; the original smoke run therefore did not include that new script.

Logs, raw JSON, run input lists, and hashes are retained beside this file.
