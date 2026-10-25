# IEEE 1800 global constraints — split probes

## Standards

- IEEE 1800-2017 §18.5.9 / IEEE 1800-2023 §18.5.8: global constraints and
  active random objects.
- IEEE 1800-2017 §18.5.10 / IEEE 1800-2023 §18.5.9: the solver must provide a
  uniform value distribution over legal value combinations.

## Environment and evidence

- DAN-DESKTOP, Slurm job 3486, 1 CPU / 1 GiB, Icarus 13.0-devel `cc25756d1`.
- Eight compile/run pairs (four probes under each edition) completed with
  `compile_rc=0` and `run_rc=0`. Each process had a 30-second process-group
  timeout; the whole job ran from 16:04:54Z to 16:05:23Z.
- Raw logs, timing/RSS, executable hashes and scheduler output are under
  `remote-results/job-3486/`.

## Results

- G1, the standard 8-bit heap case, passes all 20 randomizations in both
  editions (`rc=1`, `left.v <= v < right.v`, `bad=0`). Its joint 24-bit
  randomization emits: `Warning: a joint randomization component is too large
  to enumerate exactly; it is sampled against the hard constraints, not
  uniformly over its solutions (further similar warnings suppressed).`
- G1S, the 4-bit-per-object control, passes 200 checks in both editions
  (`bad=0 left_lt=165`) and emits no sampling warning.
- G2, a rand child object's constraint plus its parent's constraint, passes 50
  checks in both editions (`bad=0`).
- G3, a child behind a non-rand handle treated as state, passes 50 checks in
  both editions (`bad=0`).

The warning is the only conformance gap: the compiler explicitly reports that
large joint components are not sampled uniformly, contrary to 2017 §18.5.10 /
2023 §18.5.9. The small exact-enumeration control has no warning and passes its
directed distribution check. The lead filed [#843](https://github.com/dsellerbrock/iverilog-uvm/issues/843).

After #843, the audit total is 108 issues: §6 38, §10 2, §11 8, §12 7, §15 2,
§18 12, §19 1, §20 12, §21 11, §23 5, §25 7, §26 1, and §27 2. The new
filing in this tranche is one issue under §18.5.10 / 2023 §18.5.9.

## Dedupe

Open and closed searches for `too large to enumerate`,
`not uniformly over its solutions`, `uniform value distribution joint`,
`uniform value distribution`, `uniform over legal value combinations`,
`joint randomization`, `sampled against the hard constraints`, and
`uniform constraint solver` found no matching issue. Earlier broad hits on
#478, #491, #832, and #840 were reviewed in the first attempt and are unrelated.
