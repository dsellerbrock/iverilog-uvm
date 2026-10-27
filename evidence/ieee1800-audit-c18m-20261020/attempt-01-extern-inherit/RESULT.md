# IEEE 1800 external-constraint and inheritance probe, Slurm job 3476

## Standards

- IEEE 1800-2017 §§18.5.1–18.5.2, pp. 510–511.
- IEEE 1800-2023 §§18.5.1–18.5.2, pp. 529–531.
- The checked rules include explicit versus implicit prototypes, the empty-constraint behavior for an uncompleted implicit prototype, required errors for missing explicit/duplicate/colliding blocks, name-based inherited replacement, inherited constraints, virtual `randomize()` dispatch, and pure-constraint implementation.

## First run and limitation

- DAN-DESKTOP Slurm job 3476; 1 CPU / 1 GiB. Icarus 13.0-devel `cc25756d1`; hashes, logs and complete per-edition table are under `remote-results/job-3476/results/`. Slurm accounting is disabled.
- The positive source declared its classes and external blocks inside a module. It failed to compile in both editions (`compile_rc=34`, run `NA`), first with `syntax error` at line 8 (`constraint C::p1`) and then parser-cascade errors. No positive behavior was measured.
- n1, n2, n4, n5 and n6 failed compilation in both editions. n1 reported `Extern constraint 'p' has no out-of-body definition in class 'X'.`; n4 reported `A pure constraint may only be declared in a virtual class.`; n5 reported `Non-virtual class 'X' does not implement inherited pure constraint 't'.`; n6 reported `Constraint 't' is already declared pure in this class.` n2 failed at syntax parsing (`I give up.`), so the duplicate-body rule was not isolated.
- n3 (`constraint p; constraint p { x == 1; }` in the same class) unexpectedly compiled in both editions (rc=0) with only a static-variable-initialization warning. It was not run in this first harness. This is a candidate §18.5.1 validation gap, but the test layout needs a compilation-unit-scope rerun before classification.
- Existing local test `sv_constraint_prototype_collision_fail.v` checks an explicit extern prototype plus a second implicit prototype; it is not the same case as a prototype plus a block. Existing external-constraint passing tests put classes at compilation-unit scope. Therefore the module-local syntax failure above is not classified as a simulator gap yet.

## Dedupe

Open+closed searches and directly reviewed broad matches (#456, #418, #831, #681, #12) are recorded in `dedupe-open-closed.txt`. The reviewed issues cover dynamic constraint override specifiers, coupled parent/child object solving, static `constraint_mode`, scope `randomize()`, and general randomization features; none directly matches the declaration rules here. Corrected minimal probes are pending lead direction.
