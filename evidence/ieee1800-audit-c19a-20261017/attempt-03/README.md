# Clause 19 bisection attempt 03 — array-default bin removed

Slurm job 2258 removed only `bins others[] = default;` from a copy of the
original probe. That copy compiled and ran in both editions, confirming the
array-default declaration as the construct behind the original line-9 parse
failure. The same two `get_inst_coverage` output-argument assertions failed
with `n=0,d=0`; other bin-distribution, iff, and weight checks passed.

The generated source, per-edition output, and raw Slurm result are preserved
beside this note.
