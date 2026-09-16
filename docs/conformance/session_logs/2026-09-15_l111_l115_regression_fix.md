# L111/L115 broad-qualification regressions — root cause and fix (2026-09-15)

See `docs/conformance/BLOCKERS.md`'s **L117** entry for the full write-up.
This log records the investigation trail and evidence pointers.

## Trigger

The L106-L116 compiler batch's own `.github/ivtest_gate.sh` "integrated"
gate (first of seven) exited nonzero after the batch was frozen for broad
qualification (candidate `cd4cf1260c27569bcc4ee0b5cc254ab0138529ad`,
semantic `a689e79df`):

```
Total=6014, Passed=6006, Failed=3, Not Implemented=2, Expected Fail=3
GATE FAIL: unexplained new ivtest failures:
  sv_constraint_dist_boolean_subject
  sv_randomize_global_ordered_fail
  sv_randomize_global_ordered_fail_2023
```

No further gate (json/uvm/nfa/releases/frontend/makecheck) had run — the
batch's own qualification runner stopped at the first failure, before
anyone root-caused it or attempted a re-run.

## Isolating the true regression (two false starts, worth recording)

1. **`git log --oneline 053e07d373c..cd4cf1260`** looked like a clean
   linear range but isn't: `053e07d373c` (the last confirmed-passing
   qualification revision, L96-L105) is **not an ancestor** of
   `c45760199` (the PR #286 squash-merge commit that later commits build
   on). `git bisect` across that range still works (it uses
   merge-base reachability, not linearity) but is easy to misinterpret —
   always check `git merge-base --is-ancestor` before trusting a `..`
   range's ordering.
2. `vvp_reg.pl -f <custom-subset-list-file>` reproducibly fails both
   `sv_randomize_global_ordered_fail*` entries with a harness-internal
   `Failed - running iverilog`, **at every revision tested**, including
   ones where direct `iverilog`+`vvp` invocation (no harness) proves the
   real behavior is correct. This is a bug in that specific `-f` code
   path, unrelated to the compiler; do not use it to test isolated
   reducers — either run the harness's real full sweep (no `-f`) or drive
   `iverilog`/`vvp` directly.
3. `./driver/iverilog` (uninstalled, source-tree) embeds an absolute
   `IVL_ROOT` baked in at `./configure` time pointing at
   `local-install/lib/ivl`. Running it after `make -j4` without an
   intervening `make install` silently tests whatever engine was
   installed **last**, not the one just built — this produced two
   entirely spurious "still broken" results (`bbc6c2b78`, `415823320`)
   that vanished once `make install` was added back before each test.

Once both traps were known, direct `iverilog -g<edition> -o out.vvp
<test>.v && vvp out.vvp` after a full `make -j4 && make install` at each
candidate commit gave a clean, reproducible signal, confirmed 3-5x per
data point.

## Root causes

See BLOCKERS.md L117 for the full description. Short version:

- `sv_randomize_global_ordered_fail`(`_2023`): `vvp/vvp_z3.cc`,
  `836ec3b19` (L111 lane) narrowed an unconditional reject to only fire
  when a coupled cyclic-randc component also touches a `dist`, silently
  accepting the pure-ordering-coupled case instead.
- `sv_constraint_dist_boolean_subject`: `elaborate.cc`, `a689e79df`
  (L115 lane) added a new wide-constant IR terminal format (`"C:..."`)
  that the dist weight-shape parser was never taught, so any wide
  constant in a dist weight/item stopped parsing as a terminal at all.

## Fix verification

- Direct compile+run, byte-for-byte diff against gold (one gold line
  corrected for an earlier, non-regressing message rename): all three
  tests match exactly.
- Full `.github/ivtest_gate.sh` legacy sweep re-run against the fix (with
  `local-install/bin` correctly prepended to `PATH` — a third, unrelated
  methodology trap this investigation also hit and corrected: the gate
  script does not set `PATH` itself, so an inherited PATH pointing at a
  system `iverilog`/`vvp` — e.g. an oss-cad-suite install — is silently
  tested instead of the worktree's own build). See `gate.log` in this
  evidence directory for the run this log accompanies.

## Scope discipline

Both fixes are the minimum needed to restore each lane's own
pre-regression behavior; neither touches the lane's actual new
capability (L111's coupled randc+dist solving, L115's wide-constant
constraint transport generally), and neither reopens any other closed
`L##`/`DD-0##` entry.
