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

## P02 singleton process boundary

P01 checkpoint a5788c259 is the last integrated good revision. On it, both
editions compile but the singleton process reducer exits 1 at time zero
(parent and child process handles equal), and singleton wait/disable control
exits 1 at time 10 (wait fork incorrectly waited for a sibling). Raw logs/VVP
are in `p02-red`. The patch restricts dll_target::proc_block wrapper elimination
to NetBlock::SEQU. NetBlock::emit_proc dispatches here; downstream VVP lowering
already supports a singleton join/join_any using one fork/p and one join.

Both LRMs 9.3.2 establish each parallel statement as a process; 9.6.1/9.6.3
scope wait/disable to descendants; 9.7 describes independent process handles
and controls; 18.14.1/18.14.2 require hierarchical parent RNG seeding. Read local
2017 lines 14535 and 35315 onward, and 2023 lines 15622 and 36818 onward,
in addition to the parallel-block sections cited above.

Tests cover identity, completed status, exactly one parent RNG draw per child,
task/sequential controls, empty singleton children, sibling wait/disable
isolation, suspended delay/resume, and child kill releasing join without
killing its caller. Focused gate: 4/4 legacy and 4/4 JSON pass; neighbors:
55/55 legacy and 31/31 JSON pass. Commands follow the same root make/install
and paired-focus conventions, using regress-campaign-p02 lists.

Independent review: no actionable VVP defect; verified backend singleton
counts and test timing. Preserving the construct exposes existing non-VVP
translation limitations (tgt-vhdl fork and tgt-vlog95 join_any unsupported).
Those targets are not claimed qualified by this VVP process-boundary fix.
No translation workaround is included. Integrated gates remain pending.

P02 make check and integrated hard gate exited 0. Legacy: total 4646, passed
4641, failed 0, not implemented 2, expected fail 3; name diff clean. VPI
103/103, negative 149/149, runtime invariants pass. Full JSON: 1535 tests,
0 failures, exit 0. Real-DPI UVM still pending.

Application milestone preparation inspected the existing process-change replay
commands only. The historical Caliptra launcher invokes the prior output-root
script and its coordinator failed looking for a new-root result. Any fresh
replay must use a new output root and the campaign compiler explicitly; this
historical launch is not evidence of a fresh application pass. No application
source or harness has been changed during P02.

P02 real-DPI UVM exited 0: 355 passed, 0 failed, 0 skipped (-g2012). All
required local gates passed. P02 closes the singleton VVP process-boundary
fix only. Combined P03/P01/P02 source remains unmerged; remote CI is still
required before merge. No broad process, application, UVM-standard, or formal
qualification claim follows from these three fixes. Next: current Z01 verification.


## Z01A — bounded joint integral solve-before stages (in progress)

Baseline b9de0be7f rejects a legal root-local ordering in a parent/child
constraint graph in both -g2017 and -g2023. Reducer and red logs are under
../evidence/campaign-20260908/z01a. Verified IEEE 1800-2017 18.5.9/18.5.10
and IEEE 1800-2023 18.5.8/18.5.9 against the local editions. Stage variables
are uniform over feasible distinct assignments, not weighted by the number
of later completions; partially ordered variables occur as late as possible.

The joint solver now computes canonical-property sink distances and samples
distinct stage projections from already-complete component tables, then
uniformly samples the remaining fiber. The existing 1024-tuple ceiling is
unchanged. Ordered dist, active randc, and non-PROP ordering remain explicit
unsupported boundaries. Cycles fail. Existing non-joint ordering is untouched.

Both-edition standalone tests pass: ordered marginal/conditional fibers,
coupled three-stage chain, latest placement of a partially ordered variable,
two child-owned ordering instances, aliases, replay, frozen variables,
callbacks, and UNSAT value rollback. Negative tests cover cycles, array-element
ordering, active randc, ordered dist, and 1024/1025 tuple boundary preservation.
Static-storage aliases in ordering are not specifically qualified here.

An initial test incorrectly required RNG rollback on failure. IEEE 18.6.3
requires random-variable preservation and no post_randomize callback; the
existing transaction restores values/history, not RNG state. Removed only
that unsupported test assumption, retaining deterministic successful replay.
The first paired focus passed 36 legacy tests but failed six JSON comparisons
because JSON has separate stdout/stderr gold files. Added those files and
updated the obsolete unsupported-order expectation; final paired focus and
integrated gates are pending. No semantic gate has been waived.

Independent source review found no actionable defect and requested coupled
three-stage, child-owner, ordered-cap and ordered-dist coverage; all added.
Z01 remains open beyond this bounded implementation. No broader IEEE, UVM,
application DV or formal completion is asserted.

Final paired focus passed 38/38 legacy and 38/38 JSON, exit 0. make check
passed. Reviewer confirmed all requested additions, with no further findings.
Integrated and real-DPI UVM are running; full JSON follows integrated because
the harnesses share ivtest output paths. Source fingerprint is in z01a/fingerprint.txt.

Z01A integrated gate exited 0: legacy 4652 total, 4647 passed, zero failed,
2 not implemented, 3 expected failures; name comparison clean. VPI 103/103,
negative 149/149, runtime invariants 15/15. Full JSON and real-DPI UVM pending.

Z01A full JSON exited 0: 1541 tests, zero failures. Real-DPI UVM is the
remaining required local gate.

Z01A real-DPI UVM exited 0: 355 passed, 0 failed, 0 skipped (actual -g2012).
All required local gates and independent review pass. Close only bounded
canonical integral joint ordering; parent Z01 remains open. Remote CI is
required before merge. Next selection: reverify C01 because discarding a
requested inline constraint could invalidate successful DV checking.


## C01 — refuse successful inline-constraint omission (in progress)

On baseline 8f298eefe, both -g2017 and -g2023 compile the selected foreach
reducer with a warning and return randomize success while addr is 412736472
instead of the requested 123. Evidence: ../evidence/campaign-20260908/c01.
Verified both editions' 18.7 requirement that inline constraints apply along
with object constraints. The shared make_randomize_with_expr fallback now
increments Design::errors and issues a hard diagnostic, preventing codegen
without changing the owned expression/task construction path. Existing
specific errors suppress the generic fallback message as before.

Five permanent rejection sites exercise implicit object calls, scope-form
class properties, explicit expressions, task-style calls and std::randomize
with an object argument. Existing selected-foreach/clog2 diagnostic gold gains
one error apiece. Historical sv_randomize_with_unresolvable_dropped explicitly
expected warning-and-success; it now requires CE with an exact diagnostic.
This removes a misleading success expectation, not a supported feature.
Empty with blocks, zero-iteration dynamic foreach, adjacent constraints and
successful task calls remain covered by positive tests in both editions.

Independent review found no actionable defect. A suspected empty nested-set
regression was checked against the parser: that shape was already rejected,
so no translator expansion was made. Empty top-level blocks bypass the item
loop and zero-iteration dynamic templates retain nonempty IR. The new 2023
JSON rejection test initially differed only in include-path spelling; its
source configuration now follows the existing direct-source edition pattern.
Final paired focus passed 24/24 legacy and 21/21 JSON. Required integrated,
full JSON, real-DPI UVM and make check remain pending. This ticket only closes
silent constraint omission; unsupported legal shapes remain unimplemented.

First integrated run: one legacy failure, sv_constraint_foreach_hierarchical.
Its source explicitly expected successful randomize with a dropped hierarchical
item. Converted it to CE with the lowering diagnostic (thereby still testing
parser reachability); added JSON coverage for both historical discard tests.
No compiler source changed. Other 4650 legacy cases passed; VPI 103/103,
negative 149/149, runtime 15/15. Focus and integrated will rerun without an
expected-failure waiver. make check passed; UVM remains running on same source.

C01 final focus: 25/25 legacy and 23/23 JSON, exit 0. Review accepts both
historical-test conversions as exact lowering diagnostics without a broader
feature claim. Integrated rerun exited 0: 4656 total, 4651 passed, zero
failed, 2 not implemented, 3 expected failures; name comparison clean.
VPI 103/103, negative 149/149, runtime invariants 15/15. Full JSON and UVM pending.

C01 full JSON exited 0: 1547 tests, zero failures. Real-DPI UVM exited 0:
355 passed, zero failed/skipped (actual -g2012). All required local gates
and independent review pass. Close the silent-discard defect only; no claim
that unsupported foreach/clog2 shapes are implemented. Remote CI/merge
remain pending. Worktree audit unchanged; unrelated trees remain preserved.
Next: current U01 unmodified application frontier at this coherent milestone.


## U01 replay and L01 prerequisite boundary

At c57fbe3c5, one fresh unmodified OpenTitan runtime row was rebuilt using
pinned 7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19 and native Python 3.13/FuseSoC.
Core: lowrisc:dv:top_darjeeling_xbar_dbg_sim:0.1, original xbar_smoke config,
providers and timescale; no explicit seed override. Compilation passed in
3.298s. Runtime timed out after 300.052s (124) with the same scoreboard error
at 1681844ps and outstanding-request failure. No application pass is claimed.
Exact commands, compiler/corpus fingerprints and source/provider metadata:
../evidence/campaign-20260908/u01/result.json and matrix logs. Corpus stayed clean.

A 10-second UVM_HIGH/unbuffered diagnostic replay of this fresh bytecode
(trace-high.json/log) no longer crashes in enum comparison. It shows the first
routing divergence at 977768ps: host address 0x2309 is assigned to rv_dm__dbg
by the scoreboard, while the DUT sends it to soc_dbg_ctrl__jtag. The actual
ranges are 0..0x1ff and 0x2300..0x231f respectively. Later comparison errors
are consequences of this earlier mismatch, not the causal reducer.

lookup.sv reduces the failure without UVM: nested foreach visits both devices'
ranges even when its enclosing loop selected one device. Both Icarus editions
fail; Slang 11.0.448 accepts both editions; Verilator 5.050 executes correct
membership. The grammar's special identifier-prefix alternative introduces
an extra loop and shadows the prefix, unlike its expression-prefix alternative.
IEEE 2017/2023 12.7.3 and Annex foreach syntax have a terminal loop-variable
list; prefix selections belong to the target. Existing dual-dimension test
comments cite 11.7 incorrectly and assert the erroneous extra-loop behavior.

U01 is suspended at this explicit coordinator boundary. Its reducer, full
fresh replay and contract are preserved under u01. L01 is the sole active
implementation blocker; after its semantic gates pass, resume the exact smoke.


L01 changes only the existing identifier-prefix grammar action: retain the
selection expression in the enclosing scope, declare only terminal indices,
and build one foreach. The grammar productions and Bison automaton are
unchanged (563 shift/reduce, 1122 reduce/reduce; raw parse.output identical).
The synthesized PEIdent retains source/lexical position, the prefix list is
freed separately, and existing terminal index-type inference is preserved.

Both-edition lookup, constant selectors, selected-row-only traversal, explicit
outer loops and normal multidimensional loops pass. Undefined and empty/comma
prefixes are rejected. The old dual_dim test asserted a false extra outer loop;
it now tests proper selection and explicit nested traversal. Independent review
found no semantic issue, verified identical Bison output, and noted an empty
prefix diagnostic pointing to line 1. Changed that diagnostic to the foreach
location and reran build/focus before integrated validation.

A diagnostic associative-string member probe still creates an int loop key
and executes zero iterations with both the retained pre-L01 compiler and the
campaign compiler. This is DD-002, outside L01; old-compiler bytecode was used
only for that diagnostic comparison, not as qualification evidence. No claim
of associative-string member foreach completion is made.

L01 final focus passes 53/53 legacy and 34/34 JSON, exit 0. make check
passes. Final raw Bison output remains identical to baseline. Integrated and
real-DPI UVM are running; full JSON follows integrated.

L01 integrated gate exited 0: legacy 4662 total, 4657 passed, zero failed,
2 not implemented, 3 expected failures; name comparison clean. VPI 103/103,
negative 149/149, runtime 15/15. Full JSON and real-DPI UVM remain pending.

L01 full JSON exited 0: 1554 tests, zero failures. Real-DPI UVM remains
the required local semantic gate; U01 replay follows the validated checkpoint.

L01 real-DPI UVM exited 0: 355 passed, zero failed/skipped (-g2012).
All required local semantic gates and review pass. Checkpoint implementation
as awaiting the required U01 application replay, not CLOSED. Worktree audit
unchanged; no sibling trees removed. Next: rebuild the same smoke into a fresh
u01-after-l01 root with unchanged application sources, providers and options.

Post-L01 application replay uses b0ac00f47 in u01-after-l01, with the same
core/options/providers and a fresh build. Compile passed (3.262s). Source list
and all 360 exported source files match the pre-fix replay byte-for-byte;
input-comparison.json records this. Runtime still pending at this checkpoint.

Post-L01 replay completed: runtime timeout 124 after 300.068s, with no
scoreboard comparison error; noOutstandingReqsAtEndOfSim_A remains at
5344083913 ps. Diagnostic high-verbosity/scb_logging trace checks all four
request routes and the first three responses. The fourth request (0x35cc,
source 0x3c) has rsp_abort_after_d_valid_len=1 in both pre/post-L01 traces
at 2014861 ps and no host response. This is a preserved earlier frontier,
not evidence of application completion. Source inputs remain identical.

Close only L01 local scope at b0ac00f47; required remote CI before merge
remains pending. Resume U01 read-only reduction: inspect abort configuration,
member randomize and driver behavior before identifying another prerequisite.
No application source/check/traffic changes. Worktree audit unchanged.

U01 trace refinement: abort enable is legal randomized stimulus in xbar_base_vseq,
not itself a bug. Driver d_channel_thread declares rsp_done/rsp_abort inside
its forever body. After the first response, later loop entries retain rsp_done,
skip driving, and mark rsp_completed=1. A standalone class-task loop reproduces
the stale bit on entry 2 in both editions (u01-loop/reentry*.log). Both LRMs
6.21 require per-entry initialization; 6.8 gives bit default zero. Bytecode
uses autobegin.shared, with no fresh allocation/default initialization.
Suspend U01 deliberately and activate L02 only. Existing frame allocation is
the first candidate; preserve static overrides and detached capture lifetimes.

L02 candidate keeps existing own-frame allocation for automatic blocks with
direct variables or events; empty blocking scopes still collapse. Removed
the obsolete explicit-automatic-only capture helper. Permanent paired tests
exercise scalar/string/object/queue defaults, explicit initializers, static
persistence, recursion, break/continue/return, delayed inherited captures and
event-only scopes. Initial test integration had a 2023 include-path mistake
and missing JSON gold artifact, both corrected without semantic edits. Final
focus passes 69 legacy and 48 JSON, make check passes, independent review
finds no actionable issue. Integrated and real-DPI UVM gates now running;
full JSON and U01 replay remain required before local closure.

L02 integrated fails one real regression: automatic_events2, second task
instance wakes at 23 instead of 24. Totals 4664 / 4658 pass / 1 fail /
2 NI / 3 EF; VPI 103, negative 149 and runtime 15 all pass. No waiver.
Full JSON diagnostic on frame-only installed tools passes 1556/0.
UVM session 34962 remains running on those same installed tools.

Cause: scalar automatic event receivers discard ancestor source context and
broadcast across unrelated task activations. Partial vvp/event.cc repair
uses existing lexical stack recovery and filters ancestor delivery; object
mutation fanout is unchanged. Built vvp/vvp (not installed) restores exact
automatic_events2 output. Review identified another issue: probe reset copies
shared history, and signal allocation does not send initial values. New
event-history.sv reproduces wrong posedge times (2,2 rather than 2,3) with
concurrent task activations initialized to 0 and 1 before child allocation.
This regression remains in L02 scope. No new validated semantic baseline.

Resume at this exact history-initialization reducer; do not repeat broad
audit or application replay. Candidate source and permanent tests remain
uncommitted and preserved, along with evidence/u01-loop/candidate.patch.
The installed runtime is frame-only; built vvp/vvp contains partial routing
repair. Rebuild/install coherently only after correcting the remaining
mechanism, then rerun required gates and review. Last fully validated source
revision remains b0ac00f47. Remote CI and U01 checked completion remain pending.

L02 regression repair: retain distinct block frames, with scalar source
activation routing and sparse history cached in existing ancestor activation
hooks. Reset/reuse follows the existing context lifecycle; there is no map
of stale context pointers. Native/ancestor/static samples use ordered stamps.
History is seeded before comparison and the current ancestor sample is saved
after live fanout, without firing synthetic events. Static cache writes guard
against newer reentrant stamps. Object mutation fanout is unchanged.

Both original failures now pass: automatic_events2 exact gold and history
reducer 2,3. Permanent paired controls cover fixed selects, event-or, two
activations, reused frames, real/string histories, default positive-edge
partial write, and static broadcast. Review found no actionable defect.
DD-003 Boolean expression context loss and DD-004 unchanged-partial-write
default negedge are recorded with original-frame-layout evidence, not folded
into the L02 qualification claim.

Fresh baseline compiler construction exposed one-second make timestamp
granularity during restoration: restore-build said up to date and initial
focus accidentally used the original compiler. Forced make -W elab_scope.cc
rebuilt candidate, reinstalled, and confirmed matching build/install hashes
(a90ef338a4fe compiler, 875c35bd2ba2 runtime). Final focus93/50 and make check
pass. Old frame-only UVM completed355/0/0 and JSON1556/0, but are superseded
for qualification by fresh history-integrated/session7745 and
history-uvm/session61703. Full JSON and U01 replay still follow those gates.

L02 history-integrated gate exited0: 4666 total, 4661 passed, zero failed,
2 not implemented, 3 expected failures; name-diff clean. VPI103/103,
negative149/149, runtime15/15. Full JSON now running; real-DPI UVM still
pending. No semantic baseline checkpoint or U01 replay until both pass.

L02 full JSON exited0: 1558 tests, zero failures. UVM61703 is still live.
Prepared u01-after-l02/replay.sh with identical pinned core/providers/options
and fresh output root; syntax checked only, not executed before UVM passes.

L02 history UVM completed with 354 pass / 1 fail / 0 skip: recursive
`auto_task_frame_sharing_test` deadlocked. A recursive ancestor source also
had its caller child scope on the stack; stacked recovery incorrectly took
precedence over ancestor ownership. The shared scalar routing helper and
history recording now prioritize known ancestor ownership. All scalar paths
and event-or use the helper. A permanent recursive factorial/wait reducer
fails by timeout on the prior runtime and passes on the repair. Existing
frame-sharing runtime test passes; only obsolete architecture-specific test
comments changed. Independent review found no actionable finding.

Fresh recursive-history focus passed93 legacy/50 JSON, and make check passed.
Build/install compiler hashes match a90ef338a4fe and runtime7a5b2e9d9d19.
Fresh required integrated session42484 and UVM session14938 are running;
full JSON follows integrated serially. Previous integrated/JSON results are
historical, not qualification of this changed runtime. Last validated source
remains b0ac00f47. U01 replay remains prepared but unexecuted. Worktree audit
unchanged; unrelated dirty and non-ancestor trees remain preserved.

L02 recursive-history integrated exited0: 4666 total/4661 pass/0 fail/2 NI/3 EF,
name-diff clean, VPI103, negative149 and runtime15 passed. Full JSON exited0:
1558 tests, zero failures. Fresh UVM14938 remains live; its previously failing
recursive frame-sharing test now passed. U01 replay still awaits full UVM.

L02 final UVM exited0: 355 pass, zero fail/skip, real DPI umbrella loaded.
All required local semantic gates now pass on the coherent candidate.
Checkpoint the implementation before replaying pinned unmodified U01.
L02 remains awaiting application replay, and remote CI remains required before
merge. No broader lifetime or application-completion claim is made.

L02 implementation checkpoint9218751e2 passed unchanged U01 replay for its
bounded lifetime scope: runtime finishes in11.629s at36742796ps, 115 requests,
230 scoreboard items, zero UVM errors/fatals. Diagnostic UVM_HIGH/scb_logging
replay confirms115 request and115 response checks, including the previously
stalled fourth response. Actual source list and360 exported files are identical
with post-L01 input; only wrapper absolute output path differs. No corpus edits.

The application remains RUNTIME_FAIL: four SEQPRTZMB parent-process warnings.
OpenTitan dv_report_server.sv explicitly includes warnings in its failure
predicate. Do not suppress or waive them. Close only L02 bounded local scope,
resume U01 to trace parent-process guard teardown and establish baseline/reducer
evidence before any further implementation. Remote CI remains pending before
merge. Last validated implementation9218751e2; no live validation processes.

U01 coordination boundary: normal replay has4 sequence-parent warnings;
high-verbosity/scb logging replay has1 (not4). Both perform115 request and115
response checks. Pinned smoke leaves device sequences running after its body;
UVM explicitly warns on caller termination without sequence.kill. A bounded
control emits1 warning with parent.kill and0 with sequence.kill, on candidate
and pre-L02 compiler layout, both using current runtime. This does NOT exclude
an L02 runtime contribution or prove reference equivalence. Independent review
supports leaving U01 OPEN, preserving warning-count sensitivity and future
teardown/scheduling qualification. No warning suppressed, no application pass.
Suspended U01 contract lives in evidence/u01-sequence-parent/suspended-u01.yaml.

Select independent V01 for correctness impact: inflated type coverage can
falsely imply completion. Both supplied LRM editions19.11.3 explicitly define
merged bin union and give overlapping [0:1]/[1:2] value-bin example. Current
9218751e2 returns100 instead of66.666667 in both editions with explicit
merge_instances=1. Contract now V01, phase root_cause_trace, no code edits.
Broader ignored merge_instances/default weighted-average model remains a
separate obligation, not implicitly solved by an exact merged denominator.
Next command: rg -n 'dyn_type_total|dyn_type_register|covgrp_dyn'
vvp/class_type.h vvp/class_type.cc. Last validated revision9218751e2.
Worktree audit unchanged; unrelated trees preserved. No running test sessions.

V01 causal trace confirms sole registration caller covgrp_dyn_states_ discarded
resolved ranges and retained only maximum size. Candidate passes intervals for
unsized bins and merges them at type registration; scalar/fixed indexed bins
retain maximum count. Removes hit-driven denominator growth. uint128 cardinality
and guarded adjacency preserve full64-bit range without enumerating values.
Permanent paired regression covers LRM overlap, disjoint/unsampled/retired sets,
threshold accumulation, signed crossing, fixed/scalar identity and wide range.
Previous installed runtime fails first oracle; candidate passes both editions.
First focus had a2023 wrapper include-path error; corrected to existing suite
convention, rerun53legacy/43JSON passed. make check passed. Independent review
no actionable finding. Existing downstream wide-total saturation and default
merge_instances weighted averaging are not qualified by this bounded change.
Required integrated and real-DPI UVM launched; full JSON must follow integrated.
Last validated source9218751e2, V01 code uncommitted until required gates pass.

V01 live gate handles: integrated23417, UVM72988. Installed compiler
a90ef338a4fe and runtime2de024fb402d. No full JSON launched until integrated
finishes; no dependent semantic work until gates pass.

V01 integrated exited0:4668 total/4663 pass/0fail/2NI/3EF, name-diff clean,
VPI103, negative149 and runtime15 pass. Full JSON exited0:1560/0. Real-DPI
UVM72988 remains live; implementation remains uncommitted pending that gate.

V01 real-DPI UVM completed355/0/0. All required local gates and review pass.
Name this completed increment V01A to preserve the parent V01 broader scope.
Checkpoint exact constructor-dependent value-bin union, then return to selection.
Worktree audit unchanged; no unrelated files touched, no running gates. Remote
CI remains required before merge; U01 teardown qualification remains open.

V01A implementation checkpoint6eee0480c is the latest validated baseline.
Continue with V02: default merge_instances=false must average instance coverage
in both LRMs19.11.3 (table19-3 default0). Two separate50-percent instances with
complementary hits currently return100; paired reducer confirms false completion.
V02 contract activated, no implementation edits yet. Next trace existing
instance query and retention plus metadata path; reuse those rather than add a
parallel coverage engine. Remote CI and U01 teardown qualification stay open.
No live test sessions. Current exact next commands preserved in CAMPAIGN.yaml.

V02 trace checkpoint: existing instance coverage computation is
of_COVGRP_GET_INST_COVERAGE in vvp/vthread.cc8790-8970; reuse/extract rather
than duplicate. class_type has covgrp_live_ and destructor removal, but retains
only retired at_least options. Runtime type_coverage is always merged; option
merge_instances appears only in elaborate.cc accepted-name list. Actual VVP
emitter is tgt-vvp/draw_class.c (corrected tentative contract filename).
Next inspect netclass.h520-570, draw_class.c550-600 and option-property lowering
to narrow metadata/snapshot scope. No V02 implementation code changed. Latest
validated6eee0480c; no live gates. Required V02 tests/gates still outstanding.

V02 implementation underway: raw instance computation extracted without a
parallel engine; additive .covgrp_options record carries declared merge mode,
weight and get_inst option values/IR/property slots. Old VVP without record
retains old query defaults. New compilation uses normative default merge0.
Live registry plus raw-pointer retirement snapshots avoids object resurrection;
zero-denominator eligibility accompanies raw score. Direct get_inst query mode
is coupled: merge1/get_inst0 returns type coverage. IEEE19.7 disallows procedural
get_inst writes; read path supported, writes reject; weight remains mutable.
Design review caught this restriction and zero-denominator handling before
qualification. First full build passed. Coherent rebuild/install then paired
options reducer running in session2509. No required semantic gates passed yet;
last validated revision6eee0480c. New test covers weights, retirement, empty bins
and merged/public-instance dispatch. No application or unrelated-tree changes.

V02 review repair checkpoint: paired averaging/empty/parent-option and illegal
procedural get_inst write regressions added. Corrected bit width/truncation,
parent-link initialization timing and ordinary-class coverage classification.
Focused suite61 legacy/51 JSON, metadata bounds and make check completed
successfully in session50570. No integrated/full JSON/real-DPI UVM gates run.

A subsequent paired reducer four-state-option.sv fails: constructor logic2'bx1
assigned to bit get_inst_coverage becomes0 instead of1; public instance query
therefore returns100 rather than50. Integer IR atom evaluation rejects the
whole word at X/Z and the initializer falls back to default0. Do not coerce
operands before expression evaluation. Bounded independent design review
recommends ordinary compiled typed assignments via a synthesized initializer
wrapper, reusing NetEUFunc machinery and evaluating constructor actuals once.
Embedded groups lack a class scope, so this needs deliberate wrapper integration;
no replacement implementation yet. Keep V02 active and unvalidated, with
6eee0480c the last locally validated semantic revision. Worktree audit unchanged;
unrelated trees retained. No gate processes running after session50570 completed.

V02 native initializer implemented using an automatic NetEUFunc wrapper and
ordinary typed property assignments. Constructor actuals are evaluated once by
existing NetENew initialization, then read from captured properties; enclosing
object is an explicit wrapper argument. Paired original four-state reducer,
compound X/Z with once-only actual, averaging, parent-options and empty-group
controls all pass the first native build. Review found no actionable wrapper
issue and requested lexical/method/concurrency controls; these are now permanent
paired tests. Removed obsolete group IR metadata and mutable-parent evaluator
relaxation; no new four-state evaluator. Final simplified metadata rebuild/install
session2394 pending. Required focus now65 legacy/55 JSON; remaining integrated,
full JSON, real-DPI UVM, metadata/check and final review still outstanding.

V02 simplified native candidate rebuilt/installed successfully. Focus65 legacy/
55 JSON, metadata bounds and make check all pass (16028/69600 terminal0).
Installed compiler0b6a11ec37dee4c0087c7f8133e245a4d7224b5fd91456b1ef2dc3cbff54428a
and runtime7c575b6c3d221e635159b846add44e3816b9d393320dc0057e7143580131f81e.
Required integrated55247 and real-DPI UVM11766 now live; full JSON must wait for
integrated to finish because ivtest shares logs. Final independent review
requested. No source edits or dependent blocker work during these gates.
Last fully validated semantic baseline remains6eee0480c; V02 stays open.

Final independent V02 review has no remaining actionable finding; all requested
initializer controls pass. Blocker state is AWAITING_VALIDATION. Integrated,
full JSON and UVM gates remain outstanding. No coverage-parent closure implied.

V02 integrated55247 completed0:4680 total/4675pass/0fail/2NI/3EF; name-diff
clean, VPI103/103, negative149/149, runtime15/15. Full JSON56399 now running
after integrated logs are released; real-DPI UVM11766 remains live. No source
changes since native focused validation; final review passed. V02 still awaits
remaining gates before implementation checkpoint/closure and next selection.

V02 full JSON56399 completed0:1572 tests/0fail. Only real-DPI UVM11766
remains pending among local validation gates. Current installed tools unchanged.

V02 UVM11766 finished354pass/1fail/0skip with real DPI. Sole failure:
m11_coverage_cross_query_test expected merged100 from two half-covered
instances without setting merge_instances. Historical test correction explicitly
sets merge_instances1 and get_inst_coverage1 in class ct, preserving all ten
assertions including separate instance50 and start/stop. Direct2017/2023 replay
passes10/10; bounded independent review approves the semantic correction.
No compiler/runtime change. Full real-DPI UVM rerun9300 is active, logging
v02/native-uvm-final.log. Integrated/full JSON/focus/metadata/check evidence
remains valid for unchanged implementation. Last validated revision6eee0480c;
V02 remains AWAITING_VALIDATION, implementation uncommitted, remote CI before
merge. Exact next step: await9300; if pass checkpoint V02 implementation and
bounded qualification, then select next justified blocker. Do not rebuild or
start dependent work while this gate is outstanding.

V02 final real-DPI UVM9300 completed355pass/0fail/0skip. All required local
gates and review pass; implementation checkpointac60732f3. Bounded V02 local
scope closed, parentV01/U01 and remote CI remain open. Worktree audit unchanged,
unrelated trees preserved. Return to selection; assess unqualified aggregate
type-option weight semantics using current source and a concrete reducer.

V03 selected after V02 qualification: default overall arithmetic mean ignores
explicit group type_option.weight. Paired reducer onac60732f3 has type scores
50/100 and weights1/3, expected87.5, actual75. LRMs19.7.1 table19-3 require
nonnegative integral type weights for overall cumulative coverage;19.9 defines
$get_coverage overall score. Sourceof_COVGRP_GET_ALL adds each eligible type
once; no type-weight metadata exists. Exact contract activated, no implementation
edits yet. Next settle typed constant conversion and extend existing metadata/
aggregation minimally; no parentV01/U01 completion claim. No active test handles.

V03 implementation adds group type_weight(default1), extends numeric metadata
with an optional sixth field preserving old five-field input, and weights the
existing eligible type scores in GET_ALL. Zero total weight still returns100.
Declaration conversion uses ordinary elaborate_rval_expr with int target before
checking converted value0..INT32_MAX; initial low-level typed helper call skipped
scalar sizing and was corrected after -1/X controls caught it. No generic
elaborator changes. Paired exact original reducer now87.5, normal/zero and
negative/nonconstant/signed-domain controls pass. Main includes64-bit truncation,
X-to-zero conversion, INT32_MAX, unused/empty types, retirement and independent
individual type scores. Runtime old/new metadata boundary fixtures and malformed
upper bound pass; make check passes. Focus75 legacy passed; six JSON CE golds
needed only the harness-specific path prefix correction; rerun95619 live.
No integrated/full JSON/UVM gate started yet; implementation remains uncommitted.

V03 focused rerun95619 completed75 legacy/65 JSON pass. Independent review
then identified optional numeric field ambiguity: an old five-field options row
before a numbered property consumes the property index as the new weight.
Preserved reducerold-options-before-property.vvp reproduces syntax error.
Replaced sixth-field extension with separate .covgrp_type_weight tag; original
five-field grammar unchanged and runtime weight stored independently so tag
ordering does not reset it. Added permanent old-record-before-property boundary
fixture. Tagged rebuild/install14218 pending; all focus/metadata/check evidence
must be refreshed for final tagged candidate before integrated gates. No V03
integrated/full JSON/UVM run yet; last validated baselineac60732f3.

V03 tagged rebuild14218 succeeded; old-five-field-before-property reducer now
passes, as do permanent metadata boundary/malformed controls and make check
(23255 terminal0). Focus75533 passes75 legacy/65 JSON. Final independent review
has no remaining actionable finding. Required integrated87863 and real-DPI
UVM57001 started against compiler a3937469c1cd61277cbe5bfc94da22628ff2eb88db6eec7fb1612d10b3dc9246
and runtime7741c43f2751a27930cc0376a2f95e64443812923768ec4786808ba903bde0ec.
Full JSON must follow integrated serially. V03 remains uncommitted and awaiting
validation; last complete local baselineac60732f3. Next poll87863/57001, launch
full JSON after87863 completes, then checkpoint exact V03 scope only if all
required local gates pass. No dependent implementation while gates pending.

V03 integrated87863 completed0:4690 total/4685pass/0fail/2NI/3EF, name-diff
clean, VPI103/103, negative149/149, runtime15/15. Full JSON10521 launched
after integrated released ivtest logs; real-DPI UVM57001 still live. Unchanged
installed candidate, no dependent work while required gates remain pending.

V03 full JSON10521 completed0:1582/0. Real-DPI UVM57001 remains the only
pending local gate; no compiler/runtime source changes since focused validation.

V03 real-DPI UVM57001 completed355/0/0. All local gates and review pass;
implementation checkpoint2be79b2c0. Bounded group type-weight scope closed
locally; coverpoint/cross weights, procedural static options, parentV01/U01 and
remote CI remain open. Worktree audit unchanged, unrelated changes preserved.
Return to selection and verify existing S01 cross-clock overlapping implication
against current implementation and LRM rather than assuming old boundary notes
still describe present behavior. No broad audit or parallel implementation.

S01 verified as superseded for fixed-chain cross-clock overlapping implication:
0ff77277c already implements the boundary. Twelve fresh runs (three reducers,
both editions, default/legacy SVA) pass at2be79b2c0; independent review agrees.
Corrected only the stale blanket R12 exclusions. Worktree audit unchanged.
S02 candidate rejects bounded variable-length antecedents in both editions.
Before fixing it, distinguish per-endpoint consequent evaluation from the
per-start implication verdict (16.12.7); the initial three-failure expectation
is provisional and must not become a gold without resolving that distinction.

S02 semantic review rejects the provisional three-failure oracle: two starts
require two failures. Corrected retained reducer; compile rejection unchanged.
Cross-clock request counts cannot preserve parent truth with a local bump edit;
recorded design boundary and suspended S02 without implementation changes.
At the coordination boundary, selected S03 on fresh paired wrong-result evidence:
single-clock one start/two failing endpoints produces2 failures instead of1.
Existing NFA verdict dispatch is the causal mechanism. Preserve endpoint/local
state while aggregating parent truth; no multiclock architecture change in S03.
Last validated implementation2be79b2c0; all new implementation gates pending.

S03 candidate retains parent identity across consequence records, aggregates
child failure once and waits for antecedent closure/all-child success. Tracks
vacuous actions separately from nonvacuous callbacks; retains endpoint locals,
kill/disable and owner recycling. Independent review supports capacities and
EOS aggregation; corrected the unbounded antecedent oracle to remain pending.
Paired minimal red2fail/green1fail, eight mixed overlap/nonoverlap controls and
cancellation pass. Focus55legacy/20JSON passes. Old fanout golds were wrong:
reviewed per-parent expectations include vacuity and distinct-start counts.
Added single-parent/two-child strong EOS and cover-count controls. Final NFA97660,
integrated1023 and real-DPI UVM58507 pending; make check45947 passed. Full JSON
must run after integrated. Compiler61fb4516ad3825384303a70927015dc733f0ca9e233d2a63e109cc8a2622bd2c,
runtime7741c43f2751a27930cc0376a2f95e64443812923768ec4786808ba903bde0ec.
Candidate source/tests uncommitted; last fully validated revision2be79b2c0.

S03 final NFA97660 completed58/0; paired cover/EOS controls pass both editions.
Extended mixed test to16 modes including forbidden consequences and exact
same-tick failed-owner recycling. Final focus25578 passed55/20. Integrated1023
completed1: legacy4692/4687/0/2/3, negative149/runtime15 pass, VPI102/103.
The failing VPI endpoint oracle expected success before the second antecedent
closed and omitted vacuous user actions. Preserved vpi-red.log; corrected test
timing to45,5user pass actions/2nonvacuous callbacks,2fail actions and6vacuous
actions across fail/EOS properties. Independent review confirms; VPI2/2green.
JSON56004 and UVM58507 live. Repeat integrated after JSON releases sharedlogs.
No semantic source changes after the original candidate build; only clarified
source comments and strengthened/reviewed tests. Source remains uncommitted.

S03 JSON56004 completed1584/0. Final integrated65557 now runs against the
corrected reviewed VPI oracle and final strengthened tests; UVM58507 remains
live. No semantic implementation edits during validation. Current last validated
revision remains2be79b2c0 until both required gates finish. No new blocker selected.

S03 final integrated65557 completed0:4692/4687/0/2/3,VPI103,negative149,
runtime15. UVM58507 completed354/1: recursive consequent test expected1pass
for nested/throughout paths despite17 enabled starts. Reviewed stimulus has
one nonvacuous success and16vacuous successes for each; corrected only those
two expectations to17. Paired red/green and real-DPI focus5567 pass2/0.
DD005 records unchanged nonfanout paths still omitting vacuity; not repaired
opportunistically. Full real-DPI UVM14116 launched as the sole pending localgate.
No semantic implementation changes; preserve installed candidate and last
validated baseline2be79b2c0 until final UVM passes. Next poll14116, then review
final evidence and checkpoint S03 before returning to selection.

S03 full real-DPI UVM14116 completed0:355pass/0fail/0skip. All required local
gates and independent review now pass. Installed compiler61fb4516ad3825384303a70927015dc733f0ca9e233d2a63e109cc8a2622bd2c
and runtime7741c43f2751a27930cc0376a2f95e64443812923768ec4786808ba903bde0ec
remained unchanged throughout final validation. Only source-comment clarifications
followed the candidate build; no semantic code changes. Worktree audit unchanged,
unrelated changes preserved. Checkpoint exact S03 parent aggregation; retain
remote CI before merge, finite cyclic limits, S02 and DD005. Return to selection.

S03 committed61ca5f336, qualification checkpointc4851435b. Returned to selection
and reproduced DD005 with a minimal false-antecedent implication:0pass/0fail in
both editions/default+legacy modes, required1pass/0fail. Activated S04 contract.
IEEE16.12.7 defines vacuous success and16.14.1 executes the successful assertion's
pass action. Trace NFA dead-before-obligation and legacy match-only injection,
including specialized callers; no implementation edits yet. S02 remains at its
recorded cross-clock identity design boundary, and unrelated work stays preserved.


### S04 partial implementation checkpoint (2026-09-09)

At contract HEAD `30d518c06`, dirty `pform.cc` now uses one detached Reactive
pass dispatcher for NFA, fixed legacy and genvar-delay implications. Separate
monotonic request counts preserve nonvacuous callbacks while also executing
vacuous user actions. Fixed antecedents retain enabled starting attempts,
advance oldest first, and count each first failure once; startup history does
not create fictitious attempts. Arbitrary user actions retain one AST owner.

The original reducer passes both editions/default and legacy. An NFA-specific
forbidden-consequence reducer passes both editions. `progress.sv` proves two
vacuous attempts can resolve together and delayed actions do not stall later
attempts (both editions/modes). Genvar delays 1..3 were red before that slice
and green afterwards. The permanent `sv_assert_vacuous_action` pair passes
focused legacy 2/2 and JSON 2/2. Independent read-only partial review found no
actionable finding. These are partial checks, not qualification of S04.

The NFA sweep reports 52 passes/6 output mismatches: impl_window_goto,
local_var_window, midchain_unbounded, midchain_window, overlap_midchain and
window_goto_isolation (all `_nfa_only`). New vacuous actions account for visible
extra outputs, but each timing/count must be reviewed before any gold update.
No golden output has been changed at this checkpoint.

Parameter-repeat/window paths remain unfinished. Repetition vacuity can use
existing age bits below `lo`: on a failed keep, count all source ages minus
source ages shifted right by `lo`; false enabled prefixes are separate.
Already matched/mature ages must not become vacuous. Parameter-window
normalization must preserve original fixed antecedent progress and suppress
synthetic `[*1]` vacuity. Equal-span OR/AND trees require whole-tree continuation
state, not independent branch-failure actions. This is the next implementation
action; no dependent blocker is selected.

Evidence: `../evidence/campaign-20260908/s04/` including source reducers,
red/green logs, build/install logs, `nfa-partial.log`, `focus-partial.log` and
partial-change snapshot. Installed compiler SHA256
`949afd48c853bb41b4ecf21c6ea69e2a03b4437dab58e495a31f02a243c1d6eb`, runtime
`7741c43f2751a27930cc0376a2f95e64443812923768ec4786808ba903bde0ec`.
All launched processes completed. Worktree list audited; sibling states
preserved. Last fully validated implementation remains `61ca5f336`.
Required focused-neighbor, integrated ivtest/VPI/negative/runtime, full JSON,
real-DPI UVM, make check and final review gates remain pending, as does remote
CI before merge. Resume with `sed -n '21370,21820p' pform.cc` in the campaign
tree, retaining this partial patch and reducers. Do not repeat a broad audit.


### S04 parameter repetition and reviewed NFA oracles (2026-09-09)

The parameter-repeat producer now adds vacuity only for failed source ages
below the minimum length, plus false enabled prefixes. Existing mature ages
are excluded. Its user pass action uses the shared dispatcher. The window
normalizer passes `endpoint_only=true` to prevent fictitious synthetic-repeat
vacuity while its original antecedent progress remains unfinished.
`parameter-vacuity.sv` was red0/0, now green4/0 in both editions/modes.
Permanent paired parameter controls cover false prefixes, matched-age exclusion
and empty-repeat independence from keep (not complete empty-repeat timing).
Current focused legacy and JSON gates both pass4/4.

Independent stimulus enumeration resolved six NFA oracle mismatches:
impl_window_goto33starts gives32passes for each assertion; local_var_window
18starts gives17vac+1tagged pass; midchain_unbounded has9passes;
midchain_window9passes/failure85; overlap_midchain12m1passes/failures125and85;
window_goto_isolation16vacpasses/1failure. Exact times and unchanged cover/
pending diagnostics were preserved. Current NFA sweep passes58/58.

Next reducer `s04/window-vacuity.sv` compiles its flat and named equal-span
OR/AND antecedents and fails with0/0/0 versus1/1/1 at time6. Preserve original
antecedent structure before normalization. Track branch continuation and
combine with original OR/AND topology; only whole-parent loss is vacuity.
Feed enabled endpoint matches to symbolic consequence machinery and do not
count the synthetic[*1] as a separate starting attempt. Preserve asynchronous
disable and kill resets. This remains active S04, not a new blocker.

Compiler SHA256 b4791cfe0d7e19b7b9e171a75f3a71126aa03e827ff8435c5b08544d2006f486;
runtime unchanged. All builds/test handles terminal; worktrees audited and
preserved. Dirty implementation/tests retained. Last fully validated revision
61ca5f336; full integrated/JSON/UVM/check/final-review gates remain pending.
Evidence includes build/install-parameter, parameter red/green, window-red,
nfa-parameter and focus-parameter logs. Resume window lowering at
`sed -n '21845,22035p' pform.cc`; do not repeat the broad audit.


### S04 window completion and cancellation validation checkpoint (2026-09-09)

Window normalization now retains the original antecedent tree. Fixed branch
states advance by age, then OR/AND viability is combined and the existing
parent tracker emits first-loss vacuity or enabled endpoint matches. Captured
expressions retain one owner; residual tree fields are freed after lowering.
Independent review found no actionable issue. Flat/OR/AND startup red0/0/0 is
green1/1/1 in both editions/modes. Permanent window coverage adds overlap,
branch survival, Off, asynchronous disable, Kill/On and parameterized named
sequence reuse with distinct arguments. Direct reuse passes; nested aliases
fail identically on rebuilt61ca5f336 and are parked as DD-006.

All three initial permanent reducers were explicitly red with baseline61ca5f336.
A new VPI test reuses the existing callback plugin: six implication paths each
execute five vacuous user actions, including delayed NFA actions, but report no
nonvacuous success callbacks. The standalone true control supplies exactly five
callbacks. Both editions pass. Initial window NFA58/58 and make check pass.

Initial integrated session24071 completed with legacy4698total/4684pass/9fail/
2NI/3EF; VPI104/104, negative149/149, runtime15/15 all pass. The nine legacy
failures were independently traced to old pass counts and updated without
changing failure expectations or the allowlist. Corrected focus15/15legacy and
6/6JSON passes. Symbolic range/unbounded per-endpoint verdicts remain pre-existing
DD-007; override/smoke totals are explicitly compatibility checks, not complete
per-attempt qualification.

New cancellation controls then exposed in-scope errors: same-tick NBA disable
produced actions1/1/0/0/1 for legacy/NFA/repeat/window/genvar versus allzero;
between-clock disable pulse gave3/3/2 actions and1failure versus2/2/2 and0.
NFA/legacy/genvar now enter Observed before checking unsampled disable and use
a shared asynchronous abort process matching the parameter engine's existing
edge pattern. The rebuilt compiler8d49346e19bf4f6a85a8036409596e16e65ec0f057d2447defb89cdc08ffede8
passes both reducers in both editions/modes via isolated `s04/disable-tools`.
A fourth permanent paired reducer passes both editions. This compiler is NOT
installed yet: UVM session50563 remains live on window compiler
bd499c9703c00632cffaafe63349860e4bef3a14c66ddd2168dfb97d2fb3118f. Preserve the
installed tools until that exact handle is terminal. Then install current build
and run expanded focus17legacy/8JSON, VPI, NFA, integrated, full JSON, real-DPI
UVM, make check and final review. Last fully validated implementation61ca5f336.

Ponytail full and using-agent-skills were explicitly re-invoked; the correction
reuses dispatch/cancellation patterns, with unrelated discoveries record-only.
Graphify query on the canonical shared graph identified the same pform lowering
functions; no graph rebuild or worktree mutation occurred. All builds and other
test sessions are terminal; only UVM50563 remains live. Evidence is under
`s04/`, including reducer sources/logs, baseline-tools, disable-tools,
integrated-failures, focus-oracles, nfa-window and check-window logs.


### S04 final candidate installed; full gates running (2026-09-09)

Independent review found a wide-disable gap in the first abort helper: raw
`disable === 1` missed nonunit true values. Both shared and parameter abort
paths now normalize logical truth before exact-one edge detection. The
permanent cancellation pair covers10 and1x pulses that cancel, and0x that does
not, including symbolic repetition/window paths. Both editions pass. Final
code review found no remaining blocking defect; shared helpers retain existing
AST/process architecture. This is code clearance, not full qualification.

Initial UVM50563 terminated346pass/9fail/0skip. All nine failures were old
vacuity expectations independently derived from enabled clocks and antecedents:
m6b4 one vacuous pass; m9 algebra18 (16vac+2nonvac); contextual constants each6;
fixed-uarray4; nonoverlap window5; inside-property12 across4assertions;
signedness3; typed-past stable/changed6each; recursive not/until16/1,
eventual17, alwaysfailure1, nested/throughout17/0 unchanged. Expectations were
corrected without weakening failure checks; focused real-DPI UVM66913 passes9/9.

After the initial UVM became terminal, compiler
5dbb2dc757808ede38a6877a21e14746c7f3aa637421a8144ed59133f6703116 was installed.
Focus17/17legacy and8/8JSON, NFA58/58 and make check exit0 pass. Final integrated
session1309 and full real-DPI UVM11066 are live against this exact installation;
do not replace binaries. Full JSON remains pending and must run after1309 ends,
because both ivtest harnesses share log files. Review/gates must all support the
exact S04 scope before implementation checkpoint/selection. DD-007 symbolic
per-endpoint behavior remains explicitly separate and unqualified.

Only comment placement changed after the final build; no compiler semantics
changed. Last fully validated implementation remains61ca5f336. Resume by polling
1309 and11066, then full JSON after the integrated handle is terminal. Current
logs: integrated-cancellation.log,uvm-cancellation.log,focus-cancellation.log,
nfa-cancellation.log,uvm-focus-cancellation.log,check-cancellation.log under s04.


### S04 integrated retry after transient editing error (2026-09-09)

All four permanent reducers additionally pass explicit legacy mode under both
editions against installed5dbb2dc7. Integrated1309 then ended4700total/4694pass/
1fail/2NI/3EF; VPI104/104,negative149/149,runtime15/15 passed. The sole failure
was a transient syntax error in sv_assert_repeat_parameter_override while its
DD-007 comment was moved: a text insertion matched `module` inside a comment.
The source was immediately corrected and its isolated compile/run gives the
reviewed14/0 and11/1 compatibility counts. This is an editing error, not evidence
of a compiler defect, and the failed gate does not qualify the candidate.

Sources/tests are now frozen. Integrated24044 reruns into integrated-final.log;
UVM11066 remains live on the same installed compiler. Await both terminal,
then ensure FPGA install prerequisite and run full JSON. No new blocker,
allowlist relaxation, implementation commit or qualification claim was made.


### S04 required local qualification complete (2026-09-09)

All final processes terminated successfully on installed compiler
5dbb2dc757808ede38a6877a21e14746c7f3aa637421a8144ed59133f6703116 and runtime
7741c43f2751a27930cc0376a2f95e64443812923768ec4786808ba903bde0ec:
- Integrated24044:4700total,4695pass,0fail,2NI,3EF; VPI104/104,
  negative149/149,runtime15/15 (integrated-final.log).
- Full JSON74365:1592tests,0fail (json-final.log). Previously installed FPGA
  target/config were verified byte-identical to the current build before this
  run; target SHA2565b62952431824671d43ba36b385316d7919de32d1d53c86dab7090c50674a6ae.
- Full real-DPI UVM11066:355pass,0fail,0skip (uvm-cancellation.log).
- Focus17/17legacy and8/8JSON, explicit legacy2017/2023 for all four permanent
  reducers, NFA58/58, affected real-DPI UVM9/9, make check0 and independent final
  code review pass. git diff --check clean; worktree list audited and preserved.

The qualified scope is previously omitted vacuous user actions in the selected
single-clock lowering paths, including proper cancellation and callback
separation. DD-007 symbolic nonvacuous per-endpoint verdicts, S02 multiclock,
U01 teardown/application qualification and broader standards/UVM/formal
obligations remain open. Required remote CI and merge permissions remain
unchanged. This ends the S04 patch, not the continuous campaign; selection
resumes from current evidence after the implementation checkpoint.


### Selection after S04: S05 symbolic parent verdicts

S04 implementation2cdaec5bc is locally validated, with completed contract saved
under s04/completed-contract.yaml. DD-007 is selected next for standards and
parameterized-application correctness. Canonical Graphify query identifies the
symbolic repeat/window lowerers; shared graph unchanged. Fresh parent-verdict
reducer on2cdaec5bc fails in2017 and2023: early good1/0,bad0/1, then final
good2/0,bad0/2 for one start. LRM16.12.7 in both editions requires all consequent
matches to satisfy one implication evaluation;16.14.1 attaches the action to
that property truth. Exact new ACTIVE_WORK contract includes all accepted
symbolic caller shapes, cancellation and empty/nonempty match timing; no source
edit yet. Trace the actual age/endpoint mechanism before choosing parent state.
No new worktree, install, merge or dependent unvalidated baseline was introduced.


### S05 parent correction — 2026-09-10, awaiting full validation

Validated baseline remains2cdaec5bc; current branchHEADd3f7b492c plus uncommitted S05 patch. IEEE2017/2023 16.12.7 and16.14.1 require one parent verdict across all antecedent endpoints;16.12.22 distinguishes legal mixed empty/nonempty overlap from illegal empty-only overlap. Independent review confirmed contiguous matches allow the existing age bits and mature count to identify delayed owners. Terminal r_due retains only a final delayed child after HI retirement. Parents fail once before any further extension; successful parents wait for closure. Cover endpoint counting and exact-window single endpoints remain separate. Direct empty |=> windows start now; prefixed zero repetitions end on the nonempty prefix and retain next-tick |=> timing. Empty-start enable gating corrected.

Both editions reproduced early/duplicate parent verdicts and empty-window timing defects; corrected reducers pass. Permanent paired cases cover fixed/delayed, direct/prefixed, bounded/unbounded, LO0, overlapping failures/new starts, X/Z, empty nonzero-window offsets, per-instance illegal-empty rejection, async/NBA/kill mature cancellation, and Off preservation. Focus14/14 legacy+JSON passes in both default and explicit legacy engines. Neighbor focus17/17+8/8 passes after independently derived old override totals10/0,9/1 and smoke68/2,68/0; smoke now explicitly closes two remaining unbounded parents and checks70/0. VPI callback/delayed-action control1/1 passes (one nonvacuous success, one failure, vacuous action separate).

One initial focus run overlapped the VPI harness and read its shared a.out result (the failed parent's log contained the callback PASS line). Both harnesses rerun serially and pass; no semantic failure inferred from that invalid concurrent run. Initial negative gold formatting was corrected for legacy ./ivltests vs JSON ivltests and VPI compiler banner; diagnostics and callback values unchanged. DD-008 records an independent symbolic consequent-delay override defect, not repaired here.

Compiler SHA256cd91c31bd800d12808a40e182a712d8b939c280746df11ebb79637015ed9fc8d, runtime7741c43f2751a27930cc0376a2f95e64443812923768ec4786808ba903bde0ec. Source/tests frozen for integrated74997 and real-DPIUVM66260. Full JSON, NFA, make check, final review and remote CI remain required; S05 is not CLOSED. Worktree audit leaves all prior dirty/nonancestor trees preserved.

S05 full integrated session74997 terminated0:4714total4709pass0fail2NI3EF, VPI105/105, negative149/149, runtime15/15. NFA58/58, make check0 and final independent source/test review also pass. Full JSON session52285 now running separately from the terminal integrated harness; real-DPIUVM66260 remains live. No compiler/test edits during these gates. S05 remains awaiting validation.

S05 full JSON session52285 terminated0,1606tests/0failures. Only real-DPIUVM66260 remains among required local gates; remote CI remains required before merge.

S05 real-DPIUVM session66260 terminated0:355passed,0failed,0skipped with the real DPI umbrella loaded. All required local gates and final review now pass. No semantic source/test edits occurred during the full runs; installed fingerprints match. S05 is locally validated in the exact scope recorded in the matrix and blocker entry; remote CI remains required before merge. Continue campaign selection after checkpointing this increment.


### S06 selection after validated S05

S05 implementation a76c9f67a and checkpoint8de0e3c88 are committed; completed S05 contract preserved in evidence/s05. S06 promotes DD-008 because freezing a legal instance delay override silently misses the specified consequence failure. Both2017/2023 fresh reducers on S05 print EARLY1/0 then1/0 where no early pass and final0/1 are required. Graph-guided navigation led to the delay normalization path; source shows single delays fold via pform_sva_const_long before genvar handling, while symbolic range bounds already retain expressions. Exact S06 contract is active; no S06 implementation edit yet. Continue standards and causal tracing, without broad audit or another worktree.

S06 standards grounding: both LRMs16.7 Syntax16-4 define nonnegative integral cycle delays and their tick timing;23.10.2 assigns values to particular instances (with dependent-parameter updates), supported by6.20.2.16.9.1 is operator precedence, not the cycle-delay timing clause. Existing literal ##2 and preserved ##[D:D] reject ranged symbolic antecedents, so parser preservation alone cannot implement the full selected timing contract.

Reviewed representation reuses packed state instead of a pending-owner matrix: delay sampled antecedent inputs to align each endpoint with current q; for positive lag, the following original keep sample is already available and identifies the final endpoint. A separate unmatched-only real-time tracker preserves vacuity. Direct |=> maps to a synthetic prefix at start+D, with keep replay lagD+1; prefixed |=> delays both inputs byD+1. OverlapD0 retains S05 closure timing. Independent explicit per-parent child-list reference vs packed-age model passes9450traces/999810tick-by-tick comparisons, including D0/1/2/3/8, bounded/unbounded, direct/prefixed, empty-only legal cases, enable and resets. Independent review found no counterexample. Implementation and all actual compiler validation remain pending; models are design evidence, not conformance qualification.


S06 partial implementation checkpoint: uncommitted parse.y/pform.cc/pform.h implement delayed replay plus real-time vacuity, and preserve single-delay parameter expressions as exact sentinel-6 through shared normalization. Original reducer now reports0/1 without early pass in both editions. Generated explicit-reference controls pass76cases x52ticks for literals (2017) and overrides (2017/2023); model covers9450traces/999810tick comparisons. Replay-only S04 neighbor17/17+8/8 passed; current parser+replay S05 focus14/14+14/14 passes. Bison563SR/1122RR and exact conflict-state signature match S05. Builds65118/93157, installs/focus32282/92814 and Bison8903 are terminal.

Compiler fingerprinta3f662e2c3ace1dd26288fc8440785964484ce5695be46eb70baa421d4c2d45b, runtimeunchanged7741c43f2751a27930cc0376a2f95e64443812923768ec4786808ba903bde0ec. Ranged cover property with ##D remains rejected after normalization (s06/cover-delay-override.sv/.log); this is an in-scope sibling gap to repair, not grounds to qualify the patch. Permanent S06 regressions, invalid-bound/override controls, final source review and all full gates remain pending. No live processes. Last fully locally validated revisiona76c9f67a. Preserve partial diff and resume cover-path repair; no new selection or broad audit.


S06 cover sibling now shares delayed input replay but counts each true consequence endpoint and retains parents after false consequences. Independent endpoint-count reference passes76cases in both editions. Added permanent paired override, direct empty/nonempty timing, cancellation/Off and cover controls; negative/unknown instance bounds, grouped negative delay and unsupported multi-step consequence controls bring focus to16/16 legacy and16/16 JSON. Initial negative-wrapper include and JSON manifest formatting errors corrected; expected semantic diagnostics unchanged. Review found missing -6 late refusal (repaired before legacy arithmetic) and reproduced ##D (##2 q), D=-1 incorrectly accepted; shared offset normalization now preserves invalid original operands as X for existing instance-bound validation. This does not qualify unsupported broader compositions.

Build94435/install terminal, source/test freeze compiler201b7e4a2f1fc689a18dc6d2e98a1e7daffdff8a4b455f716bad10d7bede6176/runtime7741c43f2751a27930cc0376a2f95e64443812923768ec4786808ba903bde0ec. Integrated94110,NFA68316,real-DPIUVM6626 launched; full JSON waits for integrated to avoid shared harness files. Final source/test review and remaining neighbor/model/check gates pending. Worktree audit preserves prior dirty/nonancestor trees. S06 awaits validation; last validated revision remainsa76c9f67a.


S06 review exposed an additional reachable operand-width defect: a property formal colliding with a module parameter is preserved and later receives an arithmetic actual. Grouped and plain ##D wrappers widened4-bit actual arithmetic before evaluation (unsigned15+1 yielded delayed16 rather than0). Added native $bits(operand)'(operand) self-sizing before every preserved-offset path; signedness remains native. Grouped and plain |->/|=> signed/unsigned timing controls now in the permanent operand-width regression. First grouped-only correction passed18/18 focused tests but review identified zero-offset bypass before qualification; moved cast ahead of that return. Integrated94110/UVM6626 and40586/61236 stopped143 before each mutation; these are incomplete gates, not passes. NFA68316/61282 passed58/58 only on preceding candidates. Build22386 and final review active; all full gates must restart after focused green/review clearance.


S06 final shared-helper review cleared grouped/plain self-sizing, signedness, ownership, replay and -6 guards. Current focus18/18 legacy+JSON passes in both default and explicit legacy engines; S05neighbors14/14+14/14, S04neighbors17/17+8/8, generated76assertion+76cover cases in both editions,makecheck all pass. Compiler24a6c712130d707d08feccad018134cc0b16ba0c458e0892eede3a49adcb5672/runtime7741c43f2751a27930cc0376a2f95e64443812923768ec4786808ba903bde0ec frozen for integrated55376,NFA8748,real-DPIUVM91338. Full JSON must run after integrated. Broader arbitrary delay-expression parsing, formal lookup behavior and maximal-width delay arithmetic remain unqualified. No full-pass claim; S06 remains awaiting validation.

S06 integrated55376 terminated0:4732total4727pass0fail2NI3EF,VPI105/105,negative149/149,runtime15/15. NFA8748 terminated0,58/58. FullJSON95717 launched only after integrated completion; real-DPIUVM91338 remains live. No source/test mutation. S06 awaits these remaining local gates and remote CI before merge.

S06 fullJSON95717 terminated0:1624tests/0failures. Only real-DPIUVM91338 remains among required local gates; remote CI still required before merge.

S06 real-DPIUVM91338 terminated0:355passed,0failed,0skipped with real DPI umbrella loaded. All required local gates and independent review pass on frozen compiler24a6c712130d707d08feccad018134cc0b16ba0c458e0892eede3a49adcb5672/runtime7741c43f2751a27930cc0376a2f95e64443812923768ec4786808ba903bde0ec. Final fingerprints match. Qualify only the exact scope in the blocker/matrix; checkpoint then continue selection. Remote CI remains required before merge.

S06 implementation6f49fe1eb checkpointed; completed contract preserved in evidence/s06. Resume U01 application teardown qualification after S03-S06 assertion increments: existing115requests/230checked scoreboard items do not overcome SEQPRTZMB warnings. Retained reducer and suspended contract avoid another broad audit. No application mutation or new worktree. Worktree audit preserves prior dirty/nonancestor trees.

U01 fresh replay afterS06 (u01-after-s06/result.json) compiles3.181s, runs11.605s to50311632ps,115requests/230processed scoreboard items,0errors/0fatals,4SEQPRTZMBwarnings and TEST FAILED CHECKS. All360exported corpus files match postL02. Retained guard controls pass both editions: parent.kill emits1warning,sequence.kill emits0. IEEE2017/2023 9.7 requires process kill/await termination semantics; pinned UVM guard explicitly warns on caller termination and is marked contrib, not itself an1800.2 requirement. This establishes the warning mechanism, not reference-equivalent application teardown or an L02 runtime exclusion. No application edits/suppression/pass claim. Preserve U01 contract/evidence; independent S07 nested sequence alias expansion selected fromDD-006.

S07 paired current-source red confirms four No function Pair errors; direct calls pass. IEEE2017/2023 16.8 permits nested named sequences, separates declaration-owned vs instance actual name binding, and prohibits cycles including actual-argument dependency edges. Shared splicer parameterized branch recursed, bare alias branch skipped copied bodies. Candidate recurses bare bodies, releases replaced identifiers, anchors bare alias nested lookup to declaration generate, retains caller scope for substituted actuals, and tracks active declarations to stop cyclic/branching expansion before cloning. Shadow discriminator reproduced wrong caller Pair binding in the initial two-line candidate and now passes. Actual-scope discriminator preserves both module alias and caller-local sequence arguments. Independent review initially called Wrap(Wrap(a)) legal but withdrew after primary16.8 verification; it is now a negative control. Global dependency cycles across separate finite instances remain unqualified, as does broader pre-existing parameterized declaration-owned lookup.

Permanent focus12/12 legacy+JSON passes both engines; S06neighbors18/18+18/18,S04neighbors17/17+8/8,makecheck pass. Original/deep alias timing, shadow/caller binding, branching/mutual/actual-self cycle tests cover the exact increment. Final review and all full gates pending; no S07 qualification yet.

S07 final independent source/test review clear. Source/tests frozen, compiler aec395fb981c81bc1a425769e15eeab265031a4b14465632b13fe0f6f7fd95cd/runtime7741c43f2751a27930cc0376a2f95e64443812923768ec4786808ba903bde0ec. Integrated82704,NFA32199,real-DPIUVM10750 running; fullJSON waits for integrated. S07 awaiting validation, last fully validated implementation6f49fe1eb.

S07 integrated82704 terminated0:4744total4739pass0fail2NI3EF,VPI105/105,negative149/149,runtime15/15. NFA32199 terminated0,58/58. FullJSON73868 launched after integrated completion; real-DPIUVM10750 remains live. Source/test freeze preserved; S07 awaits remaining gates.

S07 fullJSON73868 terminated0:1636tests/0failures. Only real-DPIUVM10750 remains among required local gates; remote CI before merge remains required.

S07 real-DPIUVM10750 terminated0:355passed,0failed,0skipped with real DPI umbrella loaded. All required local gates and final independent review pass. Candidate source/tests unchanged throughout gates; qualify exact nested-alias scope and retain documented residuals. Checkpoint then continue campaign selection; remote CI remains required before merge.

S07 implementation4a879babc checkpointed; completed contract preserved in evidence/s07. Worktree audit preserves prior dirty/nonancestor trees. Select L03 fromDD-003 because shared automatic Boolean event state can cross-wake concurrent DV processes; retained reducer isolates a pre-existing runtime path. No new worktree or broad audit; graph/source/reducer investigation precedes any implementation.

L03 paired reducer fails2,2 instead2,3 on validated4a879babc. Source trace confirms shared Boolean input_[4]/net_ and context0 output. Independent design review rejects broadcasting a parent-derived mixed-scope result to children with different local operands. Existing alloc/reset hooks run before stack linkage and unchanged automatic defaults do not publish, so a correct per-child derived baseline needs a later initialization boundary. Preserve L03 without source edits and select L04 fromDD-004 as prerequisite. Both editions freshly reproduce false default negedge at1 on unchanged partial zero write (required real negedge3). Planned bounded extension of existing automatic hooks runs after all items and activation linkage, publishing integral slot defaults before user code; all four allocation callers and marshaling paths require review. No new scheduler architecture or dependent Boolean patch yet.

L04 candidate adds optional initialize_instance to existing automatic hooks and invokes it at all four allocation callers after state/live ownership and applicable stack setup, before argument/user writes. Root contexts remain roots. Integral signal functor keeps native net pointer and publishes its existing slot bits; reset/default semantics unchanged. Paired original/new defaults controls fail saved baseline runtime and pass candidate. Permanent4pairedcases cover default0/X,unchanged whole/partial writes,real edges,staggered concurrent/recursive frames and reuse, with watchdogs. Focus4/4 legacy+JSON,L02neighbors93/93+50/50,mixedlifetime7/7+7/7,eventcontrols14/14+14/14,makecheck and final independent review pass. Source/tests frozen with compileraec395fb981c81bc1a425769e15eeab265031a4b14465632b13fe0f6f7fd95cd/runtimee7a71e1ef3de401d931988a5dc2e1487b6f90cade059553f7412597a7b2e8abb for integrated3537,NFA96096,real-DPIUVM88516. FullJSON waits for integrated. L04 awaits validation; L03 remains suspended with no dependent patch.

L04 integrated3537 terminated0:4748total4743pass0fail2NI3EF,VPI105/105,negative149/149,runtime15/15. NFA96096 terminated0,58/58. FullJSON8381 launched after integrated completion; real-DPIUVM88516 remains live. No source/test mutation; L04 remains awaiting validation.

L04 fullJSON8381 terminated0:1640tests/0failures. Only real-DPIUVM88516 remains among required local gates; remote CI remains required before merge.

L04 real-DPIUVM88516 terminated0:355passed,0failed,0skipped with real DPI umbrella loaded. All required local gates and final review pass; frozen runtime fingerprint e7a71e1ef3de401d931988a5dc2e1487b6f90cade059553f7412597a7b2e8abb matches. Qualify exact integral default publication and checkpoint, then resume L03 on this validated prerequisite. Remote CI before merge remains required.

L04 implementation755b48a09 checkpointed; completed contract preserved in evidence/l04. Resume original L03 from preserved contract on validated initialization baseline. New post-link hook permits per-child Boolean baseline setup without broadcasting a mixed-scope parent result to unrelated child operands. No dependent patch existed before L04 qualification.

L03 post-L04 paired replays still fail2,2 instead2,3. New mixed-operands.sv similarly proves that a child-local1 must keep parent|child high while parent falls; current shared driver wakes both children at2. Both editions6.21 and9.4.2 establish activation ownership and result-change semantics. Design review now evaluates per-frame operands plus reused ancestor history, post-link initialization, and scheduling for chained expressions before source edits. Corrected malformed ACTIVE_WORK baseline to verified git revision755b48a09920bced3832409b1548c8437c884976. No new worktree; existing dirty/nonancestor trees preserved.

L03 candidate reuses scalar_event_history through a shared header, stores Boolean operands and dirty state in activation slots, and initializes derived values synchronously only for the exact frame undergoing post-link initialization. Ordinary evaluation remains queued Active; queued jobs hold no frame pointers. Static truth functions are shared and preserve existing scheduling. Review caught and fixed an older-notification static-cache overwrite guard. Paired original/mixed/chained/default/recursive controls fail saved L04 runtime and pass candidate. The retained original evidence printed PASSED but lacked finish before watchdog; permanent copy adds finish(0), preserving assertions. NBA control uses static source variables because NBAs to automatic variables are illegal. Direct PART_PV bytecode verifies pre-child ancestor writes, untouched high bits, live updates and frame reuse, baseline wrong and candidate exact. Permanent L03focus12/12legacy+JSON,L02neighbors93/93+50/50,L04neighbors4/4+4/4,makecheck and final review pass. Scope remains vvp_fun_boolean_ and supported context-preserving input chains; BUF/NOT/mux/other families remain unqualified.

L03 source/tests frozen with compiler core aec395fb981c81bc1a425769e15eeab265031a4b14465632b13fe0f6f7fd95cd/runtime da5f9d47ed813dcb145cc871be440830f4a2661c205ba9de26c992ace4142754. Integrated80505,NFA79303,real-DPIUVM93480 running; fullJSON waits for integrated. L03 awaiting validation, last fully validated implementation755b48a09.

L03 NFA79303 terminated0,58/58. Integrated80505 and real-DPIUVM93480 remain live. Source/test/install freeze preserved.

L03 integrated80505 terminated0:4760total4755pass0fail2NI3EF; fullJSON92046 launched after integrated completion. NFA58/58 passed; real-DPIUVM93480 remains live. Source/test/install freeze preserved.

L03 integrated ancillary checks passed VPI105/105,negative149/149,and runtime invariants including direct Boolean partial-history check. FullJSON92046 terminated0:1652tests/0failures. Only real-DPIUVM93480 remains among required local gates; remote CI before merge remains required.

L03 real-DPIUVM93480 terminated0:355passed,0failed,0skipped. Frozen compiler/runtime fingerprints unchanged. All required local gates and final review pass. Qualify exact shared Boolean functor/supported-chain scope and checkpoint, then continue campaign selection; remote CI remains required before merge.

L03 implementation4bcbd9c7b8ab2cdb7d602f222225f10ee5112bfb checkpointed; completed contract preserved in evidence/l03. Worktree audit preserves dirty/nonancestor sibling trees. Resume U01 unmodified application qualification in fresh u01-after-l03 output root on validated L03/L04 runtime. No application edits, warning suppression or traffic/check changes.

U01 post-L03 replay3600 terminated1 with RUNTIME_FAIL:compile3.298sec,runtime11.946sec,115requests/230scoreboarditems,0UVMerrors/0fatals,2SEQPRTZMBwarnings and TEST FAILED CHECKS at50311632ps. Pinned corpus clean7a3ad34;360exportedfiles match post-S06 exactly. Fewer warnings than prior four-warning run is not application qualification; retained reduced parent-kill mechanism does not justify suppressing warnings or a compiler patch. Preserve U01 contract/replay and select L05 from DD-002 at coordination boundary, because incorrect associative member key typing silently skips DV traversal. No L05 implementation before fresh paired reducer, primary semantics and source trace.

L05 paired retained reducer failszeroentries on validated L03. Source confirms selected-member parser actions lose selector structure (null target or unindexed path), while helper rejects indexed paths. Candidate preserves both selected-member paths, reuses evaluation-free PEIdent type lookup and terminal dimension/key types, leaving established unselected and selected-array-nonmember routes unchanged. Original paired reducer and signed16bit/classkey/inherited-parameterized controls pass initial candidate. A proposed positive same-name selector/key control failed, but review withdrew outer-binding expectation:12.7.3 references12.7.1 implicit block declarations before wholeloop, and both Slang editions bind header key to newstringindex and reject it. No runtime target-scope change was applied. Invalid control retained as evidence; valid distinct-selector/shadowed-body-key control replaces it.

L05 permanent5pairedcases cover string order/count/sum,signed16bit keys,class-method keys,inherited parameterized members,expression/bare selectors,valid body shadowing,concurrent automatic dynamic receivers and skipped fixed dimensions. Saved pre-L05 compiler fails all new cases; candidate focus10/10legacy+JSON,foreach neighbors53/53+34/34,makecheck and final review pass. Bison563shift/reduce1122reduce/reduce counts unchanged; final comment-only rebuild produces identical fingerprints. Candidate compiler98664d54ee654aae600915142565f9c8a539c4373a053cddf908000843af5226/runtime da5f9d47ed813dcb145cc871be440830f4a2661c205ba9de26c992ace4142754 frozen. Integrated66792,NFA93662,real-DPIUVM42794 running; fullJSON waits for integrated. L05 awaits validation; last fully validated4bcbd9c7b.

User requested periodic GitHub PR creation. Updated AGENTS.md to publish/update reviewable draft PRs at validated checkpoints, inspect and drain unpublished validated backlog, and record semantic heads/dependencies/CI in CAMPAIGN. Publication is authorized; merge permissions and all gates remain unchanged. Refreshed origin/main remains49505f514; no open PRs were found. First publication is the validated cohesive P03/P01/P02 fork-process batch through b9de0be7f, with the new PR-cadence policy only added above that semantic head. L05 remains frozen awaiting full local validation.


### Periodic GitHub publication requested; first batch published

User explicitly requested periodic pull requests. AGENTS.md policy checkpoint
61001162b requires publication at coherent locally validated checkpoints and
catch-up of the unpublished backlog, while preserving required CI and merge
permissions. Draft PR https://github.com/dsellerbrock/iverilog-uvm/pull/263
publishes P03/P01/P02 at validated semantic revision b9de0be7f; publication
revision a3744e5b7 adds only the PR-cadence policy. No open PR existed before
publication. Remaining cohesive batches are recorded in CAMPAIGN.yaml.

L05 source/tests/tools remain frozen. Integrated66792 exited0: 4770 total,
4765 pass, zero failures,2 not implemented,3 expected failures; VPI105/105,
negative149/149 and runtime invariants pass. NFA93662 exited0 with58/58.
FullJSON84561 started only after integrated completed; UVM42794 remains running.
Last fully locally validated semantic revision remains4bcbd9c7b.


Publication catch-up: draft PR264 publishes Z01A/C01, based on PR263;
draft PR265 publishes L01/L02, based on PR264. Exact semantic/documentation
and publication heads are recorded in CAMPAIGN.yaml. Publication trees differ
from the validated historical trees only in inherited AGENTS.md PR policy;
no L05 semantic work is included. Required remote CI/review remain pending.
L05 fullJSON84561 terminated0:1662 tests,zero failures. UVM42794 remains
running; source/tests/tools remain frozen and last validated head4bcbd9c7b.
