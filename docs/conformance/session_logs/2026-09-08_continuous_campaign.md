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
