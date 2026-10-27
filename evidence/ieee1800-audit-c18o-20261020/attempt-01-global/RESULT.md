# IEEE 1800 global constraints — initial run (inconclusive)

## Standards

- IEEE 1800-2017 §18.5.9, p. 517; IEEE 1800-2023 §18.5.8.
- Both clauses describe global constraints across active random objects. The
  2023 text further defines the active random-object set and treats references
  outside it as state variables.

## Environment and evidence

- DAN-DESKTOP, Slurm job 3485, 1 CPU / 1 GiB, Icarus 13.0-devel `cc25756d1`.
- Both editions compiled successfully. Each simulation was limited to 30
  seconds by a process-group timeout.
- Raw logs, timing/RSS records, hashes, and Slurm output are under
  `remote-results/job-3485/`.

## Results

Neither edition reached its first summary line. Both simulation processes hit
the timeout after 30 seconds (wrapper exit 124; `/usr/bin/time` reported
32.01 seconds including termination). Each emitted only the solver warning:
`a joint randomization component is too large to enumerate exactly; it is
sampled against the hard constraints, not uniformly over its solutions`.
Peak RSS was 41,692 KiB (`-g2017`) and 41,488 KiB (`-g2023`).

This result is inconclusive for the G1–G3 semantic checks. The warning is a
separate uniformity candidate, pending the exact open/closed dedupe requested
by the lead. No issue was filed based on this timeout.

## Dedupe

Searches for `"global constraint"`, `"rand object handle constraint"`,
`"sub-object randomize"`, and `"18.5.9"` found no direct match. Search hits
#478 (inline alias identity), #491 (queue solve-before target), #832 (variable
ordering diagnostics), and #840 (rand-real set membership) were reviewed and
do not cover recursive rand-child object selection. See
`dedupe-open-closed.txt`.
