# Continuous conformance campaign — 2026-09-08

## Provenance and policy

Fetched origin and fast-forwarded canonical main from 269cd208e to
49505f514. Policy-only checkpoint: 5f0be599c. Campaign branch:
agent/continuous-conformance-20260908, separate worktree. No merge/push
performed. Shared canonical graph updated from main; HTML generation hit its
existing node limit (source graph updated successfully).

Inspected all six pre-existing worktrees. Three clean feature worktrees have
HEADs not contained in refreshed origin/main; two contain dirty implementation
work; canonical main is retained. None qualifies for automatic retirement.
The original fork patch and unrelated deferred-assertion changes remain intact.

## P01 suspension / P03 prerequisite

Meaningful pre-existing fork work takes precedence over initial Z01 selection.
P01 reducers were copied without production edits, then preserved in Git stash
`campaign P01 reducers preserved while P03 prerequisite is qualified`.
The original P01 contract is in external campaign evidence. P01 is blocked by
P03 at this deliberate coordinator boundary, not declared complete.

Prior review proposed a concrete regression: retaining a trailing null/empty
fork child changes bytecode adjacency and causes an earlier function-spawned
child to execute synchronously. Current source confirms `show_stmt_fork`
emits consecutive `%fork/p`; `do_fork_` tests the following instruction for
`of_JOIN_DETACH` without excluding genuine child processes. Only `of_FORK`
and `of_FORK_P` call this helper. Named blocks and task/function continuations
use plain `%fork` or the distinct virtual-call route and must remain synchronous
where already required. Runtime reproduction is pending the fresh baseline build.

Standards read directly: local 2017 text at
`../evidence/clog2-xbar-codex-arm64-20260904/ieee2017.txt`, clauses 9.3.2/Table
9-1 (line 13241 onward), 13.4.4 (21142 onward); local 2023 PDF extracted to
`../evidence/campaign-20260908-lrm2023.txt`, corresponding lines 14329 and
22392. Both permit task-legal statements in function-spawned join_none children
and require these children to wait for parent blocking/termination. The 2023
wording expressly applies the waiting rule to all join variants; this increment
claims only the shared join_none requirement.

## Validation in progress

Fresh native ARM64 build uses repository-local prefix, -g0 -O2, Homebrew
Bison/Z3/libffi, serial make, initialized pinned uvm-core 78c06547.
Logs: `../evidence/campaign-20260908-configure.log` and
`../evidence/campaign-20260908-baseline-build.log`.
No historical green count is claimed as fresh evidence. P03 remains in_progress;
no language, UVM, application, or formal-program completion claim is made.

### P03 reproduced and focused green

Fresh baseline compiled the reducer in both -g2017 and -g2023, then exited 1
at time zero: `function child ran before parent blocked`. Logs and emitted
VVP are retained in `../evidence/campaign-20260908/p03-red/`.
Baseline SHA-256: compiler driver
`5003bb03c7ae2b53005abb9de5c671640047ed80b6176614e6083768cd8e9811`,
runtime `0cdc6a3d0f13b696c01eb5e1c48cac2e96d6a524076d38494394e5f51fb10699`,
compiler core `4246347eb1c9d2aecab1d7918f20d0ce00099a60e1742cfe41451f938326025f`.

The patch excludes `child_is_process` from the synchronous branch. It reuses
the existing queued branch, retaining its program/Reactive affinity and
existing context retention/RNG ownership before dispatch. No parser, ABI,
opcode, or resource-limit change. Named sequential continuation control and
delayed function-spawned bodies are included in the reducer.

Commands (campaign repository root):

```sh
make -C vvp -j1 && make -C vvp install
PATH="$PWD/local-install/bin:$PATH" ../evidence/arm64-tooling/resource-runner bash .github/ivtest_focus_gate.sh regress-campaign-p03-legacy.list regress-campaign-p03-vvp.list
```

Focused results: 2/2 legacy and 2/2 JSON pass (both editions). Neighbor
selection by fork/process/pure_comb/named_block basename passed 39/39 legacy
and 15/15 JSON; exact selected manifests are retained in campaign evidence.
Patched source/tool SHA-256 values are in `p03-fingerprints.txt`.
Required integrated gates and independent code review are still pending.

Independent read-only review (`review_p03`): no actionable findings after
checking helper callers, source-to-opcode distinction, context retention,
process ownership, RNG setup, reactive affinity, standards and reducer.
Reviewer inspected focused logs but did not run shared harnesses. `make check`
also passed. This review does not waive outstanding integrated gates.

P03 integrated hard gate exited 0: legacy total 4636, passed 4631, failed 0,
not implemented 2, expected fail 3; failure-name diff clean. VPI 103/103;
negative tests 149/149; runtime invariants passed. Full JSON and real-DPI UVM
are still pending. The first JSON launch used an incorrect relative guard
path and exited 127 before running tests; corrected to the ivtest-directory
paths below. This infrastructure error is not a test result.

```sh
PATH="$PWD/local-install/bin:$PATH" ../evidence/arm64-tooling/resource-runner bash .github/ivtest_gate.sh
PATH="$PWD/local-install/bin:$PATH" ../evidence/arm64-tooling/resource-runner bash .github/uvm_test.sh
cd ivtest
PATH="$PWD/../local-install/bin:$PATH" ../../evidence/arm64-tooling/resource-runner python3 ./vvp_reg.py
```

Full JSON completed with exit 0: 1525 tests, 0 failures. Real-DPI UVM
remains the only pending local integrated gate.

### P03 local closure

Real-DPI UVM exited 0: 355 passed, 0 failed, 0 skipped; actual generation mode
is -g2012 as used by the repository harness. This is repository UVM regression
evidence, not 2017/2023 UVM qualification or an IEEE 1800.2 completeness claim.
All required local gates passed on the recorded patched fingerprint. The exact
P03 implementation scope is closed locally; no PR was merged and remote CI is
still required before merge. The campaign may proceed with sequential validated
commits on this branch; no instruction requires an intervening merge. P01 and
P02 remain unresolved, application success is unchanged, and formal is unchanged.

## P01 resumed on validated P03

P03 checkpoint b9ffa4994 is the last integrated local good revision. Resumed
P01 tests from the preserved Git stash without applying unrelated original
changes. Baseline in both editions: null-child reducer exits 1 at time 5
(join_any lost its null child); empty-child reducer exits 1 at time 2 (empty
block child lost); deferred null-action control passes. Logs/emitted VVP are
in `../evidence/campaign-20260908/p01-red`.

Parser uses a dedicated parallel statement list to preserve direct nulls as
empty sequential PBlocks while ordinary nulls/assertion actions and declaration
carriers retain their existing representation. Elaborator no longer discards
empty NetBlocks when collecting parallel children. Existing backend lowering
already spawns the retained children. Singleton collapse remains P02; no claim
that all empty/singleton process semantics are complete is made here.

Both editions 9.3.2/Table 9-1 and A.6.3 ground parallel child semantics. The
null assertion control guards the separate 16.4/A.6.4 action representation.
P03 prevents newly retained trailing empty children from exposing premature
function-spawned execution.

Focused gates: 6/6 legacy, 6/6 JSON (both editions); neighbors: 74/74 legacy,
49/49 JSON, including fork/process/deferred-assertion tests. Bison fresh reports
are 541 SR/1122 RR before, 563 SR/1122 RR after. Normalizing rule/state numbers,
whitespace, and parallel-list names adds exactly one existing attribute/null
conflict signature and removes none; see `p01-bison-signature.json`. This does
not claim all parser states are identical. Source/tool hashes are in
`p01-fingerprints.txt`.

Commands: serial root make with configured Bison/flex, then make install;
paired focus gate `regress-campaign-p01-legacy.list` /
`regress-campaign-p01-vvp.list`; integrated commands as P03 above.
Integrated, real-DPI UVM, full JSON and independent review remain pending.

P01 independent review found no actionable defects. Reviewer independently
confirmed raw Bison states: baseline 1635 matches patched 1635 and 3620 after
normalization, with the same 22 rejected variable_lifetime_opt reductions.
Declaration carriers remain filtered and deferred-action semantics unchanged.
`make check` passed. Integrated suites are still running; no closure yet.

P01 integrated gate exited 0: legacy total 4642, passed 4637, failed 0,
not implemented 2, expected fail 3; name diff clean. VPI 103/103, negative
149/149 and runtime invariants passed. Full JSON exited 0: 1531 tests,
0 failures. Real-DPI UVM is still pending; P01 remains awaiting validation.

P01 real-DPI UVM exited 0: 355 passed, 0 failed, 0 skipped (-g2012). All
required local gates passed. P01 closes only null/empty parallel-child
preservation; singleton identity remains P02. No application or formal gain
is claimed. Remote CI remains required before merge.
