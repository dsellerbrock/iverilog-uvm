# IEEE 1800 external constraints and inheritance, Slurm job 3478

## Standards

- IEEE 1800-2017 §§18.5.1–18.5.2, pp. 510–511; IEEE 1800-2023 §§18.5.1–18.5.2, pp. 529–531.
- §18.5.1 requires an external block in the same scope as its class after the class declaration; it permits an uncompleted implicit prototype as an empty constraint and requires errors for missing explicit bodies, duplicate external bodies, and same-name in-class blocks.
- §18.5.2 requires inherited constraints, same-name replacement, virtual `randomize()` dispatch, and implementation of inherited pure constraints.

## Evidence

- DAN-DESKTOP, job 3478, 1 CPU / 1 GiB, 2026-10-20T15:52:15Z–15:52:16Z. Icarus 13.0-devel `cc25756d1`; hashes and raw logs are under `remote-results/job-3478/results/`. Each compiler/runtime process had a 30-second process-group timeout; Slurm accounting is disabled.
- Main compilation-unit-scope probe passes in both editions: `C ok=50 bad=0`, `C_P3 ok=50`, `B ok=50 bad=0`, `D ok=50 bad=0 n12=31 n14=19`, `DV ok=50 bad=0 n12=24 n14=26`, `E ok=50 bad=0`, `W ok=50 bad=0`.
- Package-scope external blocks pass in both editions: `PKG bad=0`.
- Module-scope external blocks fail to compile in both editions (`compile_rc=6`, no runtime). First diagnostic: `.../p18_05_1_modscope.sv:3: syntax error`; the next diagnostics say `error: Invalid module item.` Package and compilation-unit scopes pass. This is a candidate §18.5.1 scope gap.
- n1, n4, n5 and n6 fail compilation with rule-specific diagnostics in both editions, as required. Examples: `Extern constraint 'p' has no out-of-body definition in class 'X'.`; `A pure constraint may only be declared in a virtual class.`; `Non-virtual class 'X' does not implement inherited pure constraint 't'.`; `Constraint 't' is already declared pure in this class.`
- n2 (two external blocks for one prototype) compiles and runs in both editions, contrary to §18.5.1. Output is `RAN x=4`, showing the second body wins; this is a candidate gap.
- n3 (prototype plus same-name in-class block) compiles and runs in both editions, contrary to §18.5.1. Output is `RAN x=1`, showing the in-class block wins; this is a candidate gap.

## Dedupe

`dedupe-open-closed.txt` records all exact open+closed searches. The added searches for module-scope external blocks, out-of-block constraints and prototype/same-name blocks returned no results. The local `sv_constraint_prototype_collision_fail.v` checks an explicit prototype plus a second implicit prototype, a distinct collision shape. Broad issue matches #456, #418, #831, #681 and #12 were directly reviewed and do not cover these findings. Lead classification/issue filing is pending.
