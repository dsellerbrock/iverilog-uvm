# IEEE 1800 §18.4 parent/child class-handle randomization

This record qualifies a bounded behavior already implemented by the joint
constraint solver. No compiler source file changed in this candidate; the
paired tests make the direct class-handle behavior and its boundary explicit.
Clause 18 remains PARTIAL overall.

## Standards basis

- IEEE 1800-2017 and 1800-2023 §18.4: variables and constraints of an active
  `rand` object handle participate in the containing object's concurrent
  solve; randomization preserves the object handle.
- Both editions §18.5.2: inherited constraints remain active, and virtual
  `randomize()` honors the actual object's dynamic type.
- IEEE 1800-2017 §18.5.10 and 1800-2023 §18.5.9: the solver selects uniformly
  across legal value combinations unless ordering changes the distribution.
- Both editions §18.6.3: unsuccessful randomization leaves random variables at
  their previous values.

The test covers one four-combination finite parent/child domain, a derived
child and parent reached through base-typed handles, child `randc` rollback
after an unsatisfiable solve, and a non-`rand` child whose current state is
used without randomizing the child. This does not qualify arbitrary class
object graphs or all solver constraint families.

## Exact test snapshot

- Base: `9b5fad2afb4104caa816b257d5bccc40f01b8c66` (`origin/main` at run time).
- Test patch SHA-256: `4ca172fbf91c0ad9a9a9b095724ea7f677b44e93537ae75ad991722aee14e2b6`.
- Patch: [source.patch](source.patch); staged-input hashes:
  [input.sha256](input.sha256).
- Slurm job: `2188`, run directory
  `/home/dsell/slurm-runs/iverilog-uvm/A3/issue418-joint-20261017-t0t1-05/`.
- Result: job and test status both `0`; elapsed 4:25.95; 3 CPUs, 3 GiB
  requested; peak RSS 1,758,964 KiB. Host: DAN-DESKTOP, WSL2 Linux.
- Compiler: Icarus Verilog 13.0 (devel); `iverilog` SHA-256
  `e329b09f9c99bdc255a8864189558d0b0a36a1265a528e60215d650af0ee0107`;
  `vvp` SHA-256
  `c0bfa0dd94fd4b3f206df453cd1423802c5586c94bf82e49ba35ab6df5a1d010`;
  g++ 15.2.0.

## Results

- `autoconf`, configure, `make -j3`, `make check`, and `make install` passed.
- T0 focused legacy: 2/2; JSON/VVP: 2017 1/1 and 2023 1/1.
- T0 smoke: 56/56 compiler/VVP tests, 133/133 VPI tests, 152/152 negative
  tests; all smoke reproducers and VVP runtime checks completed successfully.
- T1 legacy and JSON/VVP each passed 12/12. The selection includes the new
  pair plus paired `cross_object_solve_before`, `handle_rollback`,
  `global_components`, `global_components_fail`, and `global_randc` cases.
- Every step exit code is recorded in [steps.tsv](steps.tsv). The commands,
  per-test timeout wrappers, test lists, runner output and Slurm resource
  report are preserved in [run-body.sh](run-body.sh), [slurm-job.sh](slurm-job.sh),
  [t0-2017.list](t0-2017.list), [t0-2023.list](t0-2023.list),
  [t1-legacy.list](t1-legacy.list), [t1-json.list](t1-json.list),
  [full Slurm output and resource report](slurm-2188.out.gz), and
  [ivtest-logs.tar.gz](ivtest-logs.tar.gz).

This is T0/T1 evidence only. Full T2 staging and exact-head GitHub checks remain
required before merge.
