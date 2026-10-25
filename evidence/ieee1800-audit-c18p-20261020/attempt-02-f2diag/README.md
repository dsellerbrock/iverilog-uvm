# IEEE 1800 constraint-function ordering — F2 diagnostic

- IEEE 1800-2017 §18.5.12, p. 521; IEEE 1800-2023 §18.5.11.
- The lead-directed diagnostic isolates random argument distribution, fixed
  satisfiable/unsatisfiable inline values, per-call function results, and
  splitting constraints across blocks. It runs under both editions; each
  compile and simulation has a 30-second process-group timeout.

The first function probe and its issue dedupe are in
`../attempt-01-func/`. Results and raw logs will be recorded after this run.
