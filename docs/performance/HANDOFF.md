# Performance campaign handoff prompt

Paste the block below to the implementing agent.

```text
You are implementing simulator speedups for this Icarus Verilog fork
(dsellerbrock/iverilog-uvm). Correctness is the project's first rule: a
faster but semantically different simulator is a regression.

READ FIRST, in order:
1. AGENTS.md (workflow, toolchain, gates, PR rules). It governs everything.
2. docs/performance/PERFORMANCE_PLAN.md: the plan. Section 4 lists the
   invariants you must not break. Section 5 is the measurement protocol.
   Section 6 lists the work packages (WP0-WP15).
3. evidence/perf-research-20261014/README.md and profiles/: the baseline
   measurements at 5c7b3319.
4. benchmarks/sim-hotspots/README.md and
   docs/conformance/opentitan_hotpath_optimization.md: earlier
   optimizations and the attempt ledger. Do not redo rejected ideas without
   new evidence.

AUTHORIZATION: The user authorizes a performance campaign that follows
the plan's sequence: WP0, WP1, WP2, WP3, WP4, then WP6, WP5, WP7, and so on.
- Treat each WP as one ticket. Record it in .ai/ACTIVE_WORK.yaml with ID
  PERF-WPn.
- Move the current ACTIVE_WORK content verbatim under a
  suspended_* key. Do not delete it.
- Keep one active WP at a time. Open one draft PR per WP against main.
- Never stack work on an unmerged PR. Push daily.
- Record unrelated defects in docs/conformance/DISCOVERED_DEBT.md. Do not
  fix them.

START WITH:
- WP0: benchmark corpus additions, JSON timing output, and compile-time-gated
  runtime counters, including opcode and opcode-pair histograms and
  scheduler walk length.
- WP1: read the IVL_* environment variables once at startup. Remove hot-path
  getenv and ctx_stats work. Keep every trace feature working.
- WP2: an optional --enable-pgo build with a training set disjoint from the
  evaluation set; LTO; an allocator experiment.
- WP3: word-wide 4-state operations. Begin with of_CAST2 (12.9% of behav).
  Back each converted operator with exhaustive equivalence regressions.

For every WP:
- Reproduce the baseline on your host first. Report the median of 5 runs,
  the spread, perf instructions, and max RSS.
- Simulation output must be byte-identical to the reference runtime
  (benchmarks/sim-hotspots/run.sh <ref-vvp> <new-vvp> 5).
- Run the full gates per AGENTS.md: ivtest legacy and JSON, negative, VPI,
  and UVM with real DPI. CI must be green on the exact PR head on Linux and
  macOS.
- Screening gate: at least 10% on the target benchmark, and no more than 2%
  regression elsewhere. If a candidate does not pay, revert it and record it
  in the attempt ledger.
- Update the plan's section 9 status table and add a revision-scoped
  evidence directory. Never overwrite earlier measurements.

HARD STOPS (ask the user first):
- Any change to ivtest gold output or to seeded random values.
- Any new required dependency (LLVM, mimalloc, newer Z3).
- -ffast-math, -Ofast, or any 2-state shortcut that is not proven by type and
  operator.
- Starting WP14 (native code) beyond the speed-of-light spike.
- Removing or weakening any test, diagnostic, or trace feature.

Handoff at stop: use the AGENTS.md handoff format. Include the PR URL,
CI state, and the measured before/after table.
```
