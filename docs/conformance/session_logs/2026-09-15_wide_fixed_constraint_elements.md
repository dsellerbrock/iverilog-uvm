# L115 wide fixed constraint elements — 2026-09-15

FOCUSED_TESTED; broad qualification pending. IEEE1800-2017/2023 clauses18.3,
18.4,18.5,18.8,18.13 govern the typed random variables, constraint solving,
activity, and random-state behavior exercised here.

Defined literals and parameters wider than64 bits now retain all bits through
constant constraint IR. Fixed integral/enum element access uses full vectors
for solver values, inactive-state pins, guard substitution, sampling, rollback,
and writeback, including nested class paths. The original65-bit reproducer
previously returned success with the high bit lost; both modes now preserve it.

Wide ordinary connected components use uniform full-vector tuple proposals,
accepted only when solver pins satisfy the complete constraints. After32 misses,
complete capped enumeration provides an exact uniform alternative for small
sparse domains. No arbitrary solver model or optimizer bypass substitutes for
required probability semantics. Sparse domains exceeding the cap still reject
atomically; wide cyclic, solve-before and dist remain explicit unsupported
boundaries. Existing narrow ordered/dist/cyclic component paths are retained.

Focused tests cover65/96/128-bit values, signed values, package constants,
active four-state storage, inactive unknown rejection, fixed-state pins,
UNSAT rollback and replay, independent narrow ordering, same/different seeds,
high-bit diversity, and focused unsupported cases. The unconstrained-wide
reproducer first exposed the enumeration-only candidate's limitation and is
preserved under `evidence/application-check-20260915/l115-l116-focused/diversity-baseline/`.

The prior L113 wide compile-negative is replaced by exact-bit runtime checks;
its original files are preserved in git history and the migration evidence.
The nonintegral negative keeps its rejection while removing obsolete64-bit
wording. Initial missing stdout/diagnostic golds were corrected to the actual
semantic oracle; failed harness logs are preserved.

[Final evidence](2026-09-15_wide_fixed_constraint_elements_validation.json)
records20/20 focused cases per harness and105/105 legacy,100/100 JSON neighbors.
