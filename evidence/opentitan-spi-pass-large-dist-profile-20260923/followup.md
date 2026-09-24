# Fast-path candidate follow-up

The coordinator's timed replay is recorded in `/tmp/ivl-focus-20260923/spi-dist-fastpath-flash.result.json` (VVP SHA-256 `9ddc50c3…`) and ran 120.06 seconds without completion. The stderr contains only the existing `$system`-as-task warning; the captured stdout file is empty because the bounded run was terminated before VVP flushed its buffered output.

I replayed that exact command for two seconds, sampled the process for four seconds, then sent SIGINT. This replay flushed the normal UVM startup and reached `spi_device_flash_mode_vseq`'s PRE_START banner, but produced no later UVM result. The raw sample is `fastpath-sample.txt`; `fastpath-replay.log` holds the flushed output.

The sample shows active `z3_resolve_dist_exact` range queries (the `exists_in` lambda) and Z3 SAT work. It also shows `z3_enumerate_domain` calls for other solver stages. It does not show the dist path spending time in the per-candidate `Z3_solver_check_assumptions` projection loop. The candidate binary includes the fast-path `FastItem` code; the persistent range-query frames indicate that eagerly SAT-checking all five weighted branches remains costly. The follow-up source change therefore chooses a remaining item by aggregate weight, range-checks only that item, removes it only after an UNSAT proof, and redraws. This leaves the conditional item probabilities exact while reducing the common all-feasible case to one branch SAT query.

No candidate build, install, shared test runner, or release smoke qualification was performed here. The follow-up is unverified until the coordinator's serial build and focused paired suites run; the SPI smoke remains incomplete.
