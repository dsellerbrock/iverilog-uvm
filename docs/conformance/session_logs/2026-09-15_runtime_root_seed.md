# Runtime root seed control — 2026-09-15

FOCUSED_TESTED; broad qualification pending. This is an application DV
capability preserving IEEE1800-2017/2023 18.13 hierarchical RNG behavior;
the plusarg spelling is not an IEEE requirement.

VVP recognizes one numeric `+ntb_random_seed=N` before creating its first
root thread. Decimal uint32 values, including zero, initialize the existing
design generator through the existing SplitMix64 expansion pattern. Omitting
the option preserves the prior default stream. Empty, signed, whitespace,
junk, overflowing and duplicate values fail before design-thread creation;
the option remains visible through VPI plusarg access.

Both seeded fixture harnesses pass4 cases. The permanent checker passes in
both edition modes: exact default sequence, same-seed replay, different-seed
streams, zero/max boundaries, option placement, sibling isolation, root/fork/
object hierarchy, explicit srandom overrides and malformed/duplicate failures.
The initial checker incorrectly expected unsigned display from a signed test
variable and empty loader stdout; those fixture expectations were corrected,
while requiring exact input bits, focused error and no design-thread output.

The unchanged OpenTitan Darjeeling debug-crossbar smoke passes with explicit
seed1 (137 requests,274 scoreboard items) and seed2 (189 requests,378 items).
Each reports zero UVM warnings/errors/fatals, no demoted/caught errors and
TEST PASSED CHECKS. These reuse the L108 compile artifact with the new runtime;
they are two seeded workload results, not a fresh whole-application qualification.

Usage belongs in [the UVM guide](../../uvm.md). The
[validation record](2026-09-15_runtime_root_seed_validation.json) contains
commands, source/tool fingerprints, exact logs and seeded application evidence.
