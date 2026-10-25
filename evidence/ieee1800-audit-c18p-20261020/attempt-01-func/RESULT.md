# IEEE 1800 functions in constraints — first run

## Standards

- IEEE 1800-2017 §18.5.12, p. 521; IEEE 1800-2023 §18.5.11.
- The clauses allow constraint functions with `const ref`, prohibit
  `output`/`inout`/`ref`, require function results to be treated as state, and
  give random function arguments implicit ordering.

## Environment and evidence

- DAN-DESKTOP, Slurm job 3488, 1 CPU / 1 GiB, Icarus 13.0-devel `cc25756d1`.
- All six compile attempts completed. The positive program ran in both
  editions; per-process time/RSS, hashes, and raw logs are under
  `remote-results/job-3488/`.

## Results

Under both `-g2017` and `-g2023`, the positive program compiles and runs:

- F1 value function: `F1 bad=0`.
- F2 implicit-ordering discriminator: `F2 ok=0 bad=0`. The lead predicted
  approximately 11 successful randomizations out of 200 (acceptable window
  0–27), so this needs diagnosis; no semantic conclusion is recorded yet.
- F3 `const ref` function: `F3 bad=0`.

Both negative probes fail compilation in each edition with the rule-specific
diagnostic `A function used in a constraint may not have output, inout, or
non-const ref arguments.`

## Dedupe

Open and closed searches for `"function in constraint"`,
`"constraint function call"`, `"18.5.12"`, and
`"function implicit ordering"` found closed #680 and #494. #680 is about
non-random function calls with non-rand arguments in inline constraints;
#494 covers queue-size leaves passed to constraint functions. Neither directly
covers the output/ref restrictions or F2 implicit ordering. The follow-up in
`../attempt-02-f2diag/` diagnosed the F2 failure and led to issue #844.
