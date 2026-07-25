# Full-UVM debt tracker (cost-aware regression system)

Full UVM last passed: M3B-5 head (218/218, 4x batches of 55/55/54/54,
2026-07-24 — validated the per-object and per-process RNG. Ran a full pass
because seeding changes what randomize() and $urandom draw from across the
whole library (UVM calls srandom() on every object via reseed()), and
because the companion $swrite fix touches system-task elaboration.)

Commits since full UVM: 1
Highest risk change since last full run: LOW — M13-6 primes an
edge-descriptor timing-check tracker (reachable only from a specify block
under -gspecify, which UVM does not use) plus a parse.y warning message
and a vvp.def removal. Validated with the scheduler (20/20) and uvm_core
(27/27) subsets instead of a full run; ivtest 1025/1069 with the 44-fail
baseline intact.

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
