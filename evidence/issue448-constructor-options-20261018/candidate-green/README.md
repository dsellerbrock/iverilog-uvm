# #448 candidate verification

IEEE 1800-2017 and 1800-2023 §19.7. The candidate evaluates the covergroup
definition's `option.per_instance` expression at construction, exposes the
captured value through `instance.option.per_instance`, and includes enabled
live and retired instances in the coverage report.

## Final T0/T1 run

- Host: DAN-DESKTOP Slurm, job 2588, 2 CPUs, 6 GiB, 1m32s.
- Source baseline: `ca559fd97b19bd6a56cc10f0faf8583b4077975f` plus this worktree's
  uncommitted candidate changes.
- Tool SHA-256: Icarus `2bef41d93b2d3e4e10901871b48f5200a67c1bdab09a6ef892f8a9b11e4d3f39`;
  VVP `813cd90cca0280eb53d1c13aaf971c61790c9416bd41bd8d40b56fb0ae9d9ecb`.
- T0 focused legacy: 4/4; JSON: 4/4; report-retention reproducer: 4/4.
- Smoke: 56/56 legacy cases, 133/133 VPI cases, repros, negative suite, and all
  VVP runtime scripts passed.
- T1 covergroup area: 250/250 legacy and 237/237 JSON cases.
- The existing paired §19.3 `ref` tracking tests also pass in that T1
  selection; their previously documented support limits are unchanged.
- Commands and full logs: this directory's `job-2588/` contents.

Paired positive tests cover default false, constructor-selected true/false,
captured readback after the actual changes, one retired enabled instance, one
live enabled instance and a disabled instance. The report reducer checks that
only enabled instances appear and verifies percentages and static-bin counts.
Negative paired tests reject procedural writes.

## Regression investigation

The first candidate smoke attempt found ambiguity from extending the old
five-field `.covgrp_options` record. The implementation now leaves that record
unchanged and emits a separate `.covgrp_per_instance` record; the old VVP
metadata-order test passes again.

The first T1 run also exposed five golded diagnostics whose `prop_idx` had
shifted by one. The protected baseline passed all five. Moving the new hidden
property after existing bin and parent properties preserved those IDs, after
which the full T0/T1 run passed. The final worktree contains no changes to
`.gold` or other golden-output files. Job 2588 briefly included an extra
malformed-metadata fixture/expected-stderr line; that temporary test change was
removed before this evidence note, so job 2588 exercised a strict superset of
the final test files.

## Boundary

The per-instance percentage uses the existing coverage calculator, including
dynamic-bin contributions. This report format lists static per-bin counters;
it does not print dynamic-bin counts. Windows lanes, exact-PR CI and batch T2
remain pending.
