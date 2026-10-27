# IEEE 1800 uniqueness probe results, Slurm job 3442

## Standards

- IEEE 1800-2017 §18.5.5, p. 513: unique groups contain integral scalar variables or unpacked arrays/slices with integral leaves; members have equivalent type; `randc` is prohibited; fewer than two members has no effect.
- IEEE 1800-2023 §18.5.4, p. 534: retains those rules and adds real scalar variables and real-leaf unpacked arrays/slices.
- IEEE 1800-2017 §18.4 does not permit `rand real`, so a 2017 rejection of the real probe is expected and does not test the uniqueness-specific rule.

## Evidence

- DAN-DESKTOP Slurm job 3442; 1 CPU / 1 GiB; 2026-10-20T15:20:39Z–15:20:44Z. Each compiler and runtime process had a 30-second process-group timeout. Peak RSS is unavailable because Slurm accounting is disabled.
- Icarus 13.0-devel `cc25756d1`; binary hashes and full logs are under `remote-results-3442/`. Inputs and scripts are hashed in `SHA256SUMS-input.txt`.
- Both editions: U1–U5 compiled and ran (compile/run rc=0). U1 produced `rc_ok=0 bad=500`; U2 `bad=0 distinct_perms=24`; U3 `rc=0`; U4 `rc=1 s=1`; U5 `bad=0`. U1 prints `ERROR: constraint state read: the constraint item at .../p18_05_5_unique.sv:7 is not supported by the constraint solver; randomize() fails rather than ignore it.` The compile warning says the U1 `unique` item is not representable in the solver.
- Both editions: n1 (`randc`) failed compilation with `'randc' variables cannot be used in 'unique' constraints.` The n2 mixed `byte`/`int` and n3 expression `x+1` controls compiled and ran silently (rc=0), despite the standard restrictions. The audit lead filed [#838](https://github.com/dsellerbrock/iverilog-uvm/issues/838) for these two member-validation gaps, after dedupe.
- Real-array control: `-g2017` rejects all `rand real` declarations at §18.4, as expected. `-g2023` rejects the real-array declarations with `sorry: this rand real/shortreal shape is not currently supported in IEEE 1800-2023 mode.` This behavior is covered by [#463](https://github.com/dsellerbrock/iverilog-uvm/issues/463); the evidence was posted as [comment 6294443723](https://github.com/dsellerbrock/iverilog-uvm/issues/463#issuecomment-6294443723). A separate scalar probe and the subsequent slice-shape probe are recorded in [attempt 02](../attempt-02-unique-shapes/RESULT.md).

## Dedupe

Open and closed searches for `unique constraint`, `uniqueness`, `18.5.5`, `unique randc`, `unique equivalent type`, `unique slice`, `unique array constraint`, `unique variables`, `unique expression constraint`, `unique`, `unique real`, and `rand real constraint` are recorded in `dedupe-open-closed.txt`. They found no matching uniqueness gap. The broad matches #19, #11, #27, #778, #836, #837, and #510 are unrelated. #463 was directly inspected and is the potential overlap for real arrays.

The lead filed [#838](https://github.com/dsellerbrock/iverilog-uvm/issues/838) for n2/n3 and [#839](https://github.com/dsellerbrock/iverilog-uvm/issues/839) for the slice-member refusal. The job-3457 follow-up shows the failure is specific to slice members: slice-only and mixed-with-slice groups fail in both editions, while scalar pairs, scalar-plus-whole-array, and constant-index elements pass. See [attempt 02](../attempt-02-unique-shapes/RESULT.md) for its raw evidence.
