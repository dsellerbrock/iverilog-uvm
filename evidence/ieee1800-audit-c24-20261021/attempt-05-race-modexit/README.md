# IEEE 1800 §§24.4 and 24.7 paired probes

This batch follows the audit lead's next step. It checks the race-avoidance behavior of a program port against an otherwise identical module testbench, and reruns `$exit` from a design-module initial process to resolve the module-origin case tracked in #786.

## Standard text

IEEE 1800-2017/2023 §24.4 says the program construct schedules execution “in the Reactive region, after all design events have been processed, including clocks driven by nonblocking assignments.” Section 24.3.2 says program-declared sequential code and the opposite side of program-port connections update in the Reactive region set. This should let the program sample `q` after the design's NBA and then change `d` after the design has sampled the previous value.

IEEE 1800-2017 §24.7 says `$exit` from a thread “that does not originate in an initial procedure in a program shall be ignored”; IEEE 1800-2023 §24.7 uses the same rule. The module-origin probe expects the caller to continue and the later initial process to run.

## Execution

The race and module-origin `$exit` sources are in `input/`. Paired Slurm jobs use the protected `fb584a251` toolchain, 1 CPU, 1 GiB, 5 minutes, and 30-second per-compile/per-run timeouts. Initial job 3656 completed the program race and module-origin `$exit` cases, but the module-only race control timed out after printing its three samples because that test had no finish; its logs are preserved under `remote-3656-incomplete/` and are not treated as a completed batch. I added a finish after the control samples and resubmitted in run directory `3657` as Slurm job 3658. Complete paired results, hashes, and raw logs are in `RESULT.md`. Before any new §24.4 issue, open+closed dedupe covers `testbench race`, `reactive region program sample`, `24.4`, and related program-scheduling terms. For #786, the issue is retitled to the confirmed module-origin case; its prior program-origin correction and new paired comment are recorded.
